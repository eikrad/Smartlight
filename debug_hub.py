import dirigera
import json
import os

CONFIG_FILE = 'config.json'

try:
    if not os.path.exists(CONFIG_FILE):
        print(f"Error: {CONFIG_FILE} not found!")
        print("Please run 'python bridge.py setup' first to create the configuration.")
        exit(1)
    
    with open(CONFIG_FILE, 'r') as f:
        conf = json.load(f)
    
    if 'HUB_TOKEN' not in conf or 'HUB_IP' not in conf:
        print(f"Error: {CONFIG_FILE} is missing required fields (HUB_TOKEN, HUB_IP)")
        exit(1)
    
    print(f"Connecting to hub at {conf['HUB_IP']}...")
    hub = dirigera.Hub(token=conf['HUB_TOKEN'], ip_address=conf['HUB_IP'])
    lights = hub.get_lights()
    
    if lights:
        l = lights[0]
        print("LIGHT OBJECT DIR:")
        print(dir(l))
        print("\nLIGHT OBJECT DICT:")
        print(l.__dict__)
        
        # Also check if attributes are nested
        if hasattr(l, 'attributes'):
            print("\nATTRIBUTES:")
            print(l.attributes)
    else:
        print("No lights found!")
        
except FileNotFoundError:
    print(f"Error: Could not find {CONFIG_FILE}")
    exit(1)
except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON in {CONFIG_FILE}: {e}")
    exit(1)
except KeyError as e:
    print(f"Error: Missing required key in {CONFIG_FILE}: {e}")
    exit(1)
except Exception as e:
    print(f"Error connecting to hub: {e}")
    print("Please check your HUB_IP and HUB_TOKEN in config.json")
    exit(1)
