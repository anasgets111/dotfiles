pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: sys

    property bool isArchBased: false
    property string currentWM: "other"
    property bool hasBrightnessControl: false
    property bool hasKeyboardBacklight: false

    property bool ready: false
    property int _pendingChecks: 0

    Process {
        id: pacmanCheck
        command: ["sh", "-c", "command -v pacman >/dev/null && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                sys.isArchBased = (text.trim() === "yes");
                sys._checkDone();
            }
        }
    }

    Process {
        id: brightnessCheck
        command: ["sh", "-c", "[ -d /sys/class/backlight ] && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                sys.hasBrightnessControl = (text.trim() === "yes");
                sys._checkDone();
            }
        }
    }

    Process {
        id: kbdBacklightCheck
        command: ["sh", "-c", "ls /sys/class/leds | grep -q kbd_backlight && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                sys.hasKeyboardBacklight = (text.trim() === "yes");
                sys._checkDone();
            }
        }
    }

    Component.onCompleted: {
        sys.ready = false;
        sys._pendingChecks = 3;
        sys.detectWM();
        pacmanCheck.running = true;
        brightnessCheck.running = true;
        kbdBacklightCheck.running = true;
    }

    function detectWM() {
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            sys.currentWM = "hyprland";
        else if (Quickshell.env("NIRI_SOCKET"))
            sys.currentWM = "niri";
        else
            sys.currentWM = "other";
    }

    function _checkDone() {
        sys._pendingChecks--;
        if (sys._pendingChecks <= 0) {
            sys.ready = true;
            console.log("[MainService] All checks complete, ready = true");
        }
    }
}
