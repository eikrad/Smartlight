using Toybox.WatchUi;
using Toybox.System;

class SmartLightDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() {
        System.println("DEBUG: onSelect (Button) Pressed");
        view.toggleCurrentRoom();
        return true;
    }

    function onMenu() {
        // Show Settings Menu
        view.showSettingsMenu();
        return true;
    }

    function onNextPage() {
        // Navigation should be deliberate. If we are touching the screen, ignore behaviors.
        if (view.isRequestInFlight || view.queuedBrightness != null) {
            return true; 
        }
        view.nextRoom();
        return true;
    }

    function onPreviousPage() {
        if (view.isRequestInFlight || view.queuedBrightness != null) {
            return true;
        }
        view.prevRoom();
        return true;
    }

    function onTap(clickEvent) {
        System.println("DEBUG: onTap (Screen) Pressed");
        if (clickEvent != null) {
            var coords = clickEvent.getCoordinates();
            if (view.setBrightnessByCoordinate(coords[0], coords[1])) {
                return true;
            }
            // If not near the rim, toggle the room
            view.toggleCurrentRoom();
        }
        return true;
    }

    function onDrag(dragEvent) {
        if (dragEvent != null) {
            var coords = dragEvent.getCoordinates();
            view.setBrightnessByCoordinate(coords[0], coords[1]);
        }
        return true;
    }

    function onSwipe(swipeEvent) {
        // Handle swipe gestures for brightness control as a fallback
        if (swipeEvent == null) {
            return true;
        }
        
        try {
            var direction = swipeEvent.getDirection();
            
            if (direction == null) {
                return true;
            }
            
            // Control brightness with horizontal swipes
            if (direction == WatchUi.SWIPE_LEFT) {
                view.changeBrightness(-10);
                return true;
            } else if (direction == WatchUi.SWIPE_RIGHT) {
                view.changeBrightness(10);
                return true;
            }
        } catch (e) {
            System.println("Error in onSwipe: " + e);
        }
        
        return true;
    }
}
