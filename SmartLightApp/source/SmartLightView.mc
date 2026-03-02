using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Attention;
using Toybox.Timer;

using Util;

class SmartLightView extends WatchUi.View {
    var apiClient;
    var rooms = [];
    var currentIndex = 0;
    var isLoading = true;
    var errorMsg = null;

    function initialize() {
        View.initialize();
        apiClient = new ApiClient(method(:onApiEvent));
    }

    function onLayout(dc) {
        // Load resources if needed
        apiClient.fetchRooms();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (isLoading) {
            drawCenteredText(dc, "Loading...", Graphics.COLOR_WHITE);
            return;
        }

        if (errorMsg != null) {
            drawCenteredText(dc, errorMsg, Graphics.COLOR_RED);
            return;
        }

        if (rooms.size() == 0) {
            drawCenteredText(dc, "No Rooms", Graphics.COLOR_WHITE);
            return;
        }

        var room = rooms[currentIndex];
        drawRoom(dc, room);
    }

    function drawRoom(dc, room) {
        // 1. Background Color
        var bgColor = Util.getRoomColor(room.get("color_ref"));
        dc.setColor(bgColor, bgColor);
        dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

        // 2. Brightness Indicator Bar (upper half of screen)
        drawBrightnessIndicator(dc, room);

        // 3. Room Name
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 4, Graphics.FONT_MEDIUM, room.get("name"), Graphics.TEXT_JUSTIFY_CENTER);

        // 4. Status Indicator
        var isOffline = room.get("is_offline");
        var status;
        var statusColor;
        
        // Check if room is offline (handle null/undefined values)
        if (isOffline != null && isOffline) {
            status = "OFFLINE";
            statusColor = Graphics.COLOR_RED;
        } else {
            var isOn = room.get("is_on");
            if (isOn != null && isOn) {
                status = "ON";
                statusColor = Graphics.COLOR_WHITE;
            } else {
                status = "OFF";
                statusColor = Graphics.COLOR_LT_GRAY;
            }
        }
        
        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_LARGE, status, Graphics.TEXT_JUSTIFY_CENTER);

        // 5. Brightness Text
        var bright = room.get("brightness");
        if (bright == null) {
            bright = 0;
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() * 0.75, Graphics.FONT_TINY, "B: " + bright + "%", Graphics.TEXT_JUSTIFY_CENTER);
        
        // 6. Navigation Dots (Simple)
        drawPagination(dc, currentIndex, rooms.size());
    }
    
    function drawBrightnessIndicator(dc, room) {
        var bright = room.get("brightness");
        if (bright == null) {
            bright = 0;
        }
        
        // Always draw a faint track for the brightness bar
        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        var centerX = screenWidth / 2;
        var centerY = screenHeight / 2;
        var radius = (screenWidth / 2) - 10; // 10 pixels in from the edge
        
        // Draw the background track (faint gray)
        // 180 (left) to 0 (right) clockwise is the top arc
        dc.setPenWidth(12);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, 180, 0);
        
        if (bright > 0) {
            // Draw the active brightness (yellow)
            // 0% = 180 degrees, 100% = 0 degrees (CW)
            var endAngle = 180 - ( (bright / 100.0) * 180 );
            
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, 180, endAngle);
            
            // Draw a small knob at the end of the arc for better visibility
            var endRad = endAngle * (Math.PI / 180.0);
            var knobX = centerX + radius * Math.cos(endRad);
            var knobY = centerY - radius * Math.sin(endRad);
            dc.fillCircle(knobX, knobY, 8);
        }
    }
    
    function drawPagination(dc, current, total) {
        // Draw simple dots at bottom
        var cy = dc.getHeight() - 10;
        var startX = (dc.getWidth() / 2) - ((total * 10) / 2);
        for(var i=0; i<total; i++) {
            dc.setColor(i == current ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(startX + (i * 12), cy, 3);
        }
    }

    function drawCenteredText(dc, text, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- State Management ---
    
    function showSettingsMenu() {
        var menu = new WatchUi.Menu();
        menu.setTitle("Settings");
        menu.addItem("Room Color", :room_color);
        menu.addItem("Other Settings", :other_settings);
        
        var delegate = new SettingsMenuDelegate(self);
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_UP);
    }

    function changeBrightness(delta) {
        if (rooms.size() > 0) {
            var r = rooms[currentIndex];
            var current = r.get("brightness");
            if (current == null) {
                current = 0;
            }
            var newVal = current + delta;
            if (newVal > 100) { newVal = 100; }
            if (newVal < 0) { newVal = 0; }
            
            newVal = Util.roundBrightness(newVal);
            updateRoomBrightness(r, newVal);
        }
    }

    var isInteracting = false;
    var interactionTimer = null;

    function setBrightnessByCoordinate(x, y) {
        if (rooms.size() == 0) { return false; }
        
        var width = System.getDeviceSettings().screenWidth;
        var height = System.getDeviceSettings().screenHeight;
        var centerX = width / 2;
        var centerY = height / 2;
        
        var dx = x - centerX;
        var dy = y - centerY;
        var dist = Math.sqrt(dx*dx + dy*dy);
        
        if (dist < (width / 2) * 0.6) {
            return false;
        }

        var angle = Math.atan2(-dy, dx);
        if (angle < -0.3 || angle > Math.PI + 0.3) {
            return false;
        }
        
        if (angle > Math.PI) { angle = Math.PI; }
        if (angle < 0) { angle = 0; }
        
        var brightness = ((Math.PI - angle) / Math.PI) * 100;
        var rounded = Util.roundBrightness(brightness.toNumber());
        
        var r = rooms[currentIndex];
        if (r.get("brightness") != rounded) {
            isInteracting = true; // Mark that we are actively dragging
            resetInteractionTimer();
            updateRoomBrightness(r, rounded);
        }
        return true;
    }

    function resetInteractionTimer() {
        if (interactionTimer == null) {
            interactionTimer = new Timer.Timer();
        } else {
            interactionTimer.stop();
        }
        interactionTimer.start(method(:onInteractionTimeout), 1000, false);
    }

    function onInteractionTimeout() {
        isInteracting = false;
        WatchUi.requestUpdate();
    }

    var isRequestInFlight = false;
    var queuedBrightness = null;
    var watchdogTimer = null;

    function resetWatchdog() {
        if (watchdogTimer != null) {
            watchdogTimer.stop();
        } else {
            watchdogTimer = new Timer.Timer();
        }
        watchdogTimer.start(method(:onWatchdogTimeout), 3000, false);
    }

    function onWatchdogTimeout() {
        System.println("DEBUG: WATCHDOG TIMEOUT");
        onApiEvent(:error, "Timeout");
    }

    function updateRoomBrightness(room, level) {
        System.println("DEBUG: updateRoomBrightness level=" + level);
        room.put("brightness", level);
        WatchUi.requestUpdate();
        
        if (isRequestInFlight) {
            queuedBrightness = level;
            return;
        }

        isRequestInFlight = true;
        resetWatchdog();
        apiClient.setBrightness(room.get("id"), level);
        
        if (level == 0 || level == 100) {
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(50, 100)]);
            }
        }
    }

    function nextRoom() {
        if (rooms.size() > 0 && !isInteracting) {
            currentIndex = (currentIndex + 1) % rooms.size();
            WatchUi.requestUpdate();
        }
    }

    function prevRoom() {
        if (rooms.size() > 0 && !isInteracting) {
            currentIndex--;
            if (currentIndex < 0) { currentIndex = rooms.size() - 1; }
            WatchUi.requestUpdate();
        }
    }
    
    function toggleCurrentRoom() {
        if (rooms.size() > 0 && !isInteracting) {
            var r = rooms[currentIndex];
            apiClient.toggleRoom(r.get("id"));
        }
    }

    function onApiEvent(type, payload) {
        System.println("DEBUG: onApiEvent type=" + type);
        
        isRequestInFlight = false;
        if (watchdogTimer != null) { watchdogTimer.stop(); }

        if (type == :rooms_loaded) {
            rooms = payload;
            if (currentIndex >= rooms.size()) { currentIndex = 0; }
            isLoading = false;
            errorMsg = null;
        } else if (type == :brightness_set || type == :error) {
            if (type == :error) {
                errorMsg = payload;
            } else {
                // payload is {"level" => X, "room_id" => Y}
                var confirmedLevel = payload.get("level");
                var confirmedId = payload.get("room_id");
                
                // Find the correct room even if user switched
                for (var i = 0; i < rooms.size(); i++) {
                    if (rooms[i].get("id").equals(confirmedId)) {
                        rooms[i].put("brightness", confirmedLevel);
                        break;
                    }
                }
                errorMsg = null;
            }
        }

        if (queuedBrightness != null) {
            var nextLevel = queuedBrightness;
            queuedBrightness = null;
            if (rooms.size() > 0) {
                updateRoomBrightness(rooms[currentIndex], nextLevel);
            }
        } else {
            WatchUi.requestUpdate();
        }
    }
}
