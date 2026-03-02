import json
import os
import sys
import dirigera
from dirigera.hub.auth import random_code, send_challenge, get_token
from flask import Flask, jsonify, request

# Configuration File
CONFIG_FILE = 'config.json'
# Auth Constants from library
ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
CODE_LENGTH = 128

app = Flask(__name__)
hub_interface = None

def load_config():
    if not os.path.exists(CONFIG_FILE):
        return None
    with open(CONFIG_FILE, 'r') as f:
        return json.load(f)

def save_config(ip, token):
    with open(CONFIG_FILE, 'w') as f:
        json.dump({"HUB_IP": ip, "HUB_TOKEN": token}, f)
    print(f"Configuration saved to {CONFIG_FILE}")

def setup_hub():
    print("--- Ikea Dirigera Setup ---")
    ip = input("Enter the IP address of your Dirigera Hub: ").strip()
    
    try:
        print("Starting auth sequence...")
        # 1. Generate Verifier
        code_verifier = random_code(ALPHABET, CODE_LENGTH)
        
        # 2. Send Challenge
        print("Sending challenge to hub...")
        code = send_challenge(ip, code_verifier)
        
        # 3. User Interaction
        print("\nPLEASE GO TO YOUR HUB NOW.")
        print("Press the Action Button on the bottom of the hub.")
        input("Press Enter here AFTER you have pressed the button...")
        
        # 4. Get Token
        print("Attempting to fetch token...")
        token = get_token(ip, code, code_verifier)
        
        print(f"Success! Token: {token}")
        save_config(ip, token)
        return ip, token
    except Exception as e:
        print(f"Error generating token: {e}")
        return None, None

def initialize_hub():
    global hub_interface
    config = load_config()
    
    if not config:
        print("No configuration found to start server.")
        return False
        
    try:
        hub_interface = dirigera.Hub(token=config['HUB_TOKEN'], ip_address=config['HUB_IP'])
        return True
    except Exception as e:
        print(f"Failed to connect to hub: {e}")
        return False

def _get_reachable_lights_for_room(room_id):
    """Return (list of reachable lights for room_id, None) or (None, (json_dict, status_code))."""
    if not hub_interface:
        return None, ({"error": "Hub not connected"}, 500)
    lights = hub_interface.get_lights()
    target = [l for l in lights if l.room is not None and str(l.room.id) == str(room_id)]
    if not target:
        return None, ({"error": "Room not found"}, 404)
    reachable = [l for l in target if getattr(l, "is_reachable", True)]
    if not reachable:
        return None, ({"error": "All lights in room are offline"}, 400)
    return reachable, None


# --- API Endpoints ---

@app.route('/rooms', methods=['GET'])
def get_rooms():
    if not hub_interface:
        return jsonify({"error": "Hub not connected"}), 500
    
    try:
        # Fetch all lights/controllers to group by room
        lights = hub_interface.get_lights()
        # In Dirigera, 'room' is a property of the device
        
        # Group by room
        rooms_data = {}
        for light in lights:
            # Skip lights without room assignment
            if light.room is None:
                continue
                
            r_id = light.room.id
            r_name = light.room.name
            
            if r_id not in rooms_data:
                rooms_data[r_id] = {
                    "id": r_id,
                    "name": r_name,
                    "is_on": False, # Aggregate state
                    "brightness": 0, # Aggregate
                    "is_offline": False, # Track if room is offline
                    "color_ref": getattr(light.room, 'color', 'unknown'),
                    "icon": getattr(light.room, 'icon', 'unknown'),
                    "total_lights": 0,
                    "reachable_lights": 0,
                    "can_color": False,
                    "can_temp": False
                }
            
            rooms_data[r_id]["total_lights"] += 1
            is_reachable = getattr(light, 'is_reachable', True)
            if is_reachable:
                rooms_data[r_id]["reachable_lights"] += 1
                # Capabilities: if ANY reachable light supports it
                if hasattr(light.attributes, 'color_hue') and light.attributes.color_hue is not None:
                    rooms_data[r_id]["can_color"] = True
                if hasattr(light.attributes, 'color_temperature') and light.attributes.color_temperature is not None:
                    rooms_data[r_id]["can_temp"] = True

            is_actually_on = light.attributes.is_on and is_reachable
            if light.attributes.is_on and not is_reachable:
                print(f"  [DEBUG] Light {light.id} in {r_name} is marked ON but is unreachable (no power)")

            # Aggregate state: If any light is on AND reachable, room is on
            if is_actually_on:
                rooms_data[r_id]["is_on"] = True
            
            # Aggregate brightness: Only consider lights that are ON and reachable
            # If all lights are off, use the brightness of the first light (last known value)
            current_brightness = getattr(light.attributes, 'light_level', 0)
            if current_brightness is None:
                current_brightness = 0
            
            # Track brightness for lights that are ON and reachable
            if is_actually_on:
                if "brightness_sum_on" not in rooms_data[r_id]:
                    rooms_data[r_id]["brightness_sum_on"] = 0
                    rooms_data[r_id]["brightness_count_on"] = 0
                rooms_data[r_id]["brightness_sum_on"] += current_brightness
                rooms_data[r_id]["brightness_count_on"] += 1
            
            # Also track the first light's brightness as fallback (for when all are off)
            if "brightness_fallback" not in rooms_data[r_id]:
                rooms_data[r_id]["brightness_fallback"] = current_brightness
        
        # Calculate brightness and determine offline status for each room
        for r_id in rooms_data:
            # Determine if room is offline: if ALL lights are unreachable
            if rooms_data[r_id]["reachable_lights"] == 0 and rooms_data[r_id]["total_lights"] > 0:
                rooms_data[r_id]["is_offline"] = True
                rooms_data[r_id]["is_on"] = False  # Can't be on if all lights are offline
            
            if "brightness_count_on" in rooms_data[r_id] and rooms_data[r_id]["brightness_count_on"] > 0:
                # Average of lights that are ON
                rooms_data[r_id]["brightness"] = int(rooms_data[r_id]["brightness_sum_on"] / rooms_data[r_id]["brightness_count_on"])
                # Round to nearest 10 for consistency
                rooms_data[r_id]["brightness"] = int(round(rooms_data[r_id]["brightness"] / 10.0) * 10)
            else:
                # All lights are off, use fallback value
                rooms_data[r_id]["brightness"] = int(round(rooms_data[r_id].get("brightness_fallback", 0) / 10.0) * 10)
            
            for key in ("brightness_sum_on", "brightness_count_on", "brightness_fallback", "total_lights", "reachable_lights"):
                rooms_data[r_id].pop(key, None)
        return jsonify({"rooms": list(rooms_data.values())})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/rooms/<room_id>/toggle', methods=['POST'])
def toggle_room(room_id):
    reachable_lights, err = _get_reachable_lights_for_room(room_id)
    if err:
        return jsonify(err[0]), err[1]
    try:
        any_on = any(l.attributes.is_on for l in reachable_lights)
        target_state = not any_on
        for light in reachable_lights:
            light.set_light(lamp_on=target_state)
        return jsonify({"success": True, "new_state": target_state})
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/rooms/<room_id>/brightness', methods=['POST'])
def set_brightness(room_id):
    reachable_lights, err = _get_reachable_lights_for_room(room_id)
    if err:
        return jsonify(err[0]), err[1]
    data = request.get_json(silent=True)
    if not data or data.get("level") is None:
        return jsonify({"error": "Missing 'level'"}), 400
    try:
        level = int(round(data["level"] / 10.0) * 10)
        level = max(0, min(100, level))
        for light in reachable_lights:
            light.set_light_level(light_level=level)
        return jsonify({"success": True, "level": level, "room_id": room_id})
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/rooms/<room_id>/color', methods=['POST'])
def set_room_color(room_id):
    reachable_lights, err = _get_reachable_lights_for_room(room_id)
    if err:
        return jsonify(err[0]), err[1]
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Missing JSON body"}), 400
    hue, saturation = data.get("hue"), data.get("saturation")
    if hue is None or saturation is None:
        return jsonify({"error": "Missing 'hue' or 'saturation'"}), 400
    try:
        count = 0
        for light in reachable_lights:
            if hasattr(light, "set_light_color") and hasattr(light.attributes, "color_hue"):
                light.set_light_color(hue=float(hue), saturation=float(saturation))
                count += 1
        return jsonify({"success": True, "room_id": room_id, "updated": count})
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/rooms/<room_id>/temperature', methods=['POST'])
def set_room_temperature(room_id):
    reachable_lights, err = _get_reachable_lights_for_room(room_id)
    if err:
        return jsonify(err[0]), err[1]
    data = request.get_json(silent=True)
    if not data or data.get("temperature") is None:
        return jsonify({"error": "Missing 'temperature'"}), 400
    try:
        temp = int(data["temperature"])
        count = 0
        for light in reachable_lights:
            if hasattr(light, "set_color_temperature") and hasattr(light.attributes, "color_temperature"):
                light.set_color_temperature(color_temp=temp)
                count += 1
        return jsonify({"success": True, "room_id": room_id, "updated": count})
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'setup':
        setup_hub()
    else:
        if initialize_hub():
            print("Starting Bridge Server on port 8080...")
            print("Endpoints:")
            print("  GET  /rooms")
            print("  POST /rooms/<id>/toggle")
            print("  POST /rooms/<id>/brightness (json: {level: 0-100})")
            print("\nUsing HTTPS (SSL)...")
            app.run(host='0.0.0.0', port=8080, threaded=True, ssl_context=('cert.pem', 'key.pem'))
        else:
            print("Please run 'python bridge.py setup' first!")
