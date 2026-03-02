using Toybox.Communications;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;
using Toybox.PersistedContent;

class ApiClient {
    hidden var _callback;

    function initialize(callback) {
        _callback = callback;
    }

    function getBaseUrl() {
        var ip = Application.getApp().getProperty("bridge_ip");
        var port = Application.getApp().getProperty("bridge_port");
        var useHttps = Application.getApp().getProperty("use_https");
        
        if (ip == null) { ip = "127.0.0.1"; }
        if (port == null) { port = 8080; }
        if (useHttps == null) { useHttps = true; }
        
        var protocol = useHttps ? "https://" : "http://";
        return protocol + ip + ":" + port;
    }

    function fetchRooms() {
        var baseUrl = getBaseUrl();
        System.println("DEBUG: Starting fetchRooms() to " + baseUrl);
        
        var url = baseUrl + "/rooms";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        
        Communications.makeWebRequest(url, null, options, method(:onResponse));
    }

    function toggleRoom(roomId) {
        var url = getBaseUrl() + "/rooms/" + roomId + "/toggle";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :requestType => Communications.REQUEST_CONTENT_TYPE_JSON,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, {}, options, method(:onActionResponse));
    }

    function onResponse(responseCode as Lang.Number, data as Null or Lang.Dictionary) as Void {
        System.println("DEBUG: onResponse called!");
        System.println("DEBUG: Response Code = " + responseCode);
        System.println("DEBUG: Data = " + data);
        
        if (responseCode == 200) {
            if (data != null) {
                var rooms = data.get("rooms");
                if (rooms != null) {
                    System.println("DEBUG: Extracted rooms, calling callback...");
                    _callback.invoke(:rooms_loaded, rooms);
                } else {
                    System.println("Error: 'rooms' key not found in response");
                    _callback.invoke(:error, "Invalid response format");
                }
            } else {
                System.println("Error: Response data is null");
                _callback.invoke(:error, "Empty response");
            }
        } else {
            System.println("Error: " + responseCode);
            _callback.invoke(:error, "Err: " + responseCode);
        }
    }

    function onActionResponse(responseCode as Lang.Number, data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
         System.println("DEBUG: onActionResponse code = " + responseCode);
         if (responseCode == 200) {
            fetchRooms();
        } else {
            System.println("Error in action: " + responseCode);
            _callback.invoke(:error, "Err: " + responseCode);
        }
    }

    function setBrightness(roomId, level) {
        var url = getBaseUrl() + "/rooms/" + roomId + "/brightness";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :requestType => Communications.REQUEST_CONTENT_TYPE_JSON,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        var params = {"level" => level};
        // Store roomId for the response handler
        Communications.makeWebRequest(url, params, options, method(:onBrightnessResponse));
    }
    
    function onBrightnessResponse(responseCode as Lang.Number, data as Null or Lang.Dictionary) as Void {
        System.println("DEBUG: onBrightnessResponse code = " + responseCode);
        if (responseCode == 200) {
            if (data != null && data instanceof Lang.Dictionary) {
                var level = data.get("level");
                var roomId = data.get("room_id");
                if (level != null && roomId != null) {
                    _callback.invoke(:brightness_set, {"level" => level, "room_id" => roomId});
                    return;
                }
            }
        }
        System.println("DEBUG: Brightness failed or no data, refreshing rooms...");
        fetchRooms();
    }

    function setRoomColor(roomId, hue, saturation) {
        var url = getBaseUrl() + "/rooms/" + roomId + "/color";
        var params = {
            "hue" => hue,
            "saturation" => saturation
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :requestType => Communications.REQUEST_CONTENT_TYPE_JSON,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, params, options, method(:onActionResponse));
    }

    function setRoomTemperature(roomId, temperature) {
        var url = getBaseUrl() + "/rooms/" + roomId + "/temperature";
        var params = {
            "temperature" => temperature
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :requestType => Communications.REQUEST_CONTENT_TYPE_JSON,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, params, options, method(:onActionResponse));
    }
}
