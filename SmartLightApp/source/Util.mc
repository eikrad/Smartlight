using Toybox.Graphics;
using Toybox.Lang;

/**
 * Shared utility functions (testable without UI).
 */
module Util {

    /**
     * Map room color_ref string to Graphics color constant.
     */
    function getRoomColor(colorRef) {
        if (colorRef == null) { return Graphics.COLOR_DK_GRAY; }
        if (colorRef.find("orange") != null) { return Graphics.COLOR_ORANGE; }
        if (colorRef.find("purple") != null) { return Graphics.COLOR_PURPLE; }
        if (colorRef.find("blue") != null) { return Graphics.COLOR_BLUE; }
        if (colorRef.find("pink") != null) { return Graphics.COLOR_PINK; }
        if (colorRef.find("white") != null) { return Graphics.COLOR_DK_GRAY; }
        return Graphics.COLOR_DK_GRAY;
    }

    /**
     * Round brightness to nearest 10 (0–100). Matches backend behavior.
     */
    function roundBrightness(value) {
        if (value > 100) { value = 100; }
        if (value < 0) { value = 0; }
        return ((value + 5) / 10) * 10;
    }
}
