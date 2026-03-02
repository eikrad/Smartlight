using Toybox.WatchUi;
using Toybox.System;

class SettingsMenuDelegate extends WatchUi.MenuInputDelegate {
    var view;

    function initialize(v) {
        MenuInputDelegate.initialize();
        view = v;
    }

    function onMenuItem(item) {
        if (item == :room_color) {
            if (view.rooms.size() == 0) { return; }
            var room = view.rooms[view.currentIndex];
            
            var menu = new WatchUi.Menu();
            menu.setTitle("Room Color");
            
            var hasOptions = false;
            
            if (room.get("can_temp")) {
                menu.addItem("Warm White", :warm);
                menu.addItem("Cold White", :cold);
                hasOptions = true;
            }
            
            if (room.get("can_color")) {
                menu.addItem("Red", :red);
                menu.addItem("Green", :green);
                menu.addItem("Blue", :blue);
                menu.addItem("Yellow", :yellow);
                menu.addItem("Purple", :purple);
                hasOptions = true;
            }
            
            if (!hasOptions) {
                menu.addItem("Not Supported", :none);
            }
            
            var delegate = new ColorMenuDelegate(view);
            WatchUi.pushView(menu, delegate, WatchUi.SLIDE_UP);
        } else if (item == :other_settings) {
            System.println("Other settings - not implemented yet");
        }
    }
}

class ColorMenuDelegate extends WatchUi.MenuInputDelegate {
    var view;

    function initialize(v) {
        MenuInputDelegate.initialize();
        view = v;
    }

    function onMenuItem(item) {
        if (view.rooms.size() == 0) { return; }
        var roomId = view.rooms[view.currentIndex].get("id");
        
        if (item == :warm) {
            view.apiClient.setRoomTemperature(roomId, 2202);
        } else if (item == :cold) {
            view.apiClient.setRoomTemperature(roomId, 4000);
        } else if (item == :red) {
            view.apiClient.setRoomColor(roomId, 0, 1.0);
        } else if (item == :green) {
            view.apiClient.setRoomColor(roomId, 120, 1.0);
        } else if (item == :blue) {
            view.apiClient.setRoomColor(roomId, 240, 1.0);
        } else if (item == :yellow) {
            view.apiClient.setRoomColor(roomId, 60, 1.0);
        } else if (item == :purple) {
            view.apiClient.setRoomColor(roomId, 300, 1.0);
        }
        
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

