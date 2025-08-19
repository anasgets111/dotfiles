pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import qs.Services
import qs.Services.SystemInfo

Singleton {
    id: sys

    property bool isArchBased: false
    property string currentWM: "other"
    property bool hasBrightnessControl: false
    property bool hasKeyboardBacklight: false
    property bool isLaptop: false

    property bool ready: false
    property int _pendingChecks: 0
    property var logger: LoggerService
    property bool debug: logger.debug

    property string username: ""
    property string fullName: ""
    property string uptime: ""
    property string hostname: ""
    // Process to get username, full name, and hostname
    Process {
        id: userInfoProc
        command: ["bash", "-c", "echo \"$USER|$(getent passwd $USER | cut -d: -f5 | cut -d, -f1)|$HOSTNAME\""]
        stdout: StdioCollector {
            onStreamFinished: {
                // Output: username|fullName|hostname
                var parts = text.trim().split("|");
                sys.username = parts[0] || "";
                sys.fullName = parts[1] || "";
                sys.hostname = parts[2] || "";
                sys._checkDone();
            }
        }
    }

    // Process to get uptime (in seconds)
    Process {
        id: uptimeProc
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Output: "12345.67 ..."
                sys.uptime = text.trim().split(" ")[0] || "";
                sys._checkDone();
            }
        }
    }

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

    // Detect if the machine has a lid switch (laptop)
    Process {
        id: lidCheck
        // Prefer ACPI lid path; fallback to checking SW_LID capability in input devices
        command: ["sh", "-c", "if ( [ -d /proc/acpi/button/lid ] && ls /proc/acpi/button/lid/*/state >/dev/null 2>&1 ) || grep -q 'SW_LID' /proc/bus/input/devices; then echo yes; else echo no; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                sys.isLaptop = (text.trim() === "yes");
                sys._checkDone();
            }
        }
    }

    function registerCheck(process) {
        sys._pendingChecks++;
        process.running = true;
    }

    Component.onCompleted: {
        sys.ready = false;
        sys._pendingChecks = 0;
        sys.detectWM();
        registerCheck(pacmanCheck);
        registerCheck(brightnessCheck);
        registerCheck(kbdBacklightCheck);
        registerCheck(lidCheck);
        registerCheck(userInfoProc);
        registerCheck(uptimeProc);
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
            logger.log("[MainService] All checks complete, ready = true");
        }
    }
}
