using Toybox.Test as Test;
using Toybox.Graphics;
using Toybox.Lang;

using Util;

/**
 * Unit tests for SmartLight app logic (run with: monkeyc -t ... && monkeydo ... /t).
 */
module SmartLightTest {

    (:test)
    function testGetRoomColorNull(logger) {
        Test.assertEqual(Util.getRoomColor(null), Graphics.COLOR_DK_GRAY);
        return true;
    }

    (:test)
    function testGetRoomColorOrange(logger) {
        Test.assertEqual(Util.getRoomColor("orange"), Graphics.COLOR_ORANGE);
        Test.assertEqual(Util.getRoomColor("light orange"), Graphics.COLOR_ORANGE);
        return true;
    }

    (:test)
    function testGetRoomColorBlue(logger) {
        Test.assertEqual(Util.getRoomColor("blue"), Graphics.COLOR_BLUE);
        return true;
    }

    (:test)
    function testGetRoomColorPurple(logger) {
        Test.assertEqual(Util.getRoomColor("purple"), Graphics.COLOR_PURPLE);
        return true;
    }

    (:test)
    function testGetRoomColorPink(logger) {
        Test.assertEqual(Util.getRoomColor("pink"), Graphics.COLOR_PINK);
        return true;
    }

    (:test)
    function testGetRoomColorWhite(logger) {
        Test.assertEqual(Util.getRoomColor("white"), Graphics.COLOR_DK_GRAY);
        return true;
    }

    (:test)
    function testGetRoomColorUnknown(logger) {
        Test.assertEqual(Util.getRoomColor("unknown"), Graphics.COLOR_DK_GRAY);
        return true;
    }

    (:test)
    function testRoundBrightness(logger) {
        Test.assertEqual(Util.roundBrightness(0), 0);
        Test.assertEqual(Util.roundBrightness(100), 100);
        Test.assertEqual(Util.roundBrightness(47), 50);
        Test.assertEqual(Util.roundBrightness(44), 40);
        Test.assertEqual(Util.roundBrightness(45), 50);
        Test.assertEqual(Util.roundBrightness(55), 60);
        return true;
    }

    (:test)
    function testRoundBrightnessClamp(logger) {
        Test.assertEqual(Util.roundBrightness(150), 100);
        Test.assertEqual(Util.roundBrightness(-10), 0);
        return true;
    }
}
