pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    // Tunables for brightness behavior
    property int onBatteryBrightness: 10
    property int onACBrightness: 100
    property int kbdOnBattery: 1
    property int kbdOnAC: 3
    property string kbdDevice: "asus::kbd_backlight"

    property string platformProfile: "Loading..."
    readonly property string platformInfo: "Platform: " + platformProfile
    property string ppdText: "Loading..."
    readonly property string ppdInfo: "PPD: " + ppdText
    property string cpuGovernor: "Unknown"
    property string energyPerformance: "Unknown"

    property bool onBattery: UPower.onBattery

    signal powerInfoUpdated
    signal thermalInfoUpdated

    Component.onCompleted: {
        root.refreshPowerInfo();
    }

    Component.onDestruction: {
        try {
            brightnessDebounce.stop();
        } catch (e) {}
        try {
            brightnessProcess.running = false;
        } catch (e) {}
        try {
            ppdProcess.running = false;
        } catch (e) {}
    }

    Connections {
        target: DetectEnv
        function onBatteryManagerChanged() {
            root.refreshPowerInfo();
        }
    }

    onOnBatteryChanged: {
        refreshPowerInfo();
        adjustBrightness();
    }

    // Brightness control process
    Process {
        id: brightnessProcess
        command: []
        running: false
    }

    Timer {
        id: brightnessDebounce
        interval: 250
        repeat: false
        onTriggered: {
            if (!DetectEnv.isLaptopBattery)
                return;
            brightnessProcess.running = true;
        }
    }

    function adjustBrightness() {
        if (!DetectEnv.isLaptopBattery)
            return;

        const screen = root.onBattery ? onBatteryBrightness : onACBrightness;
        const kbd = root.onBattery ? kbdOnBattery : kbdOnAC;
        const cmd = `brightnessctl set ${screen}% && brightnessctl -d ${kbdDevice} set ${kbd}`;

        brightnessProcess.command = ["sh", "-c", cmd];
        if (brightnessDebounce.running) {
            brightnessDebounce.restart();
        } else {
            brightnessDebounce.start();
        }
    }

    QtObject {
        id: reader

        function read(filePath, callback) {
            var process = processComponent.createObject(root, {
                "command": ["cat", filePath]
            });

            process.stdout.streamFinished.connect(function () {
                var data = process.stdout.text ? process.stdout.text.trim() : "";
                callback(data);
                process.destroy();
            });

            process.running = true;
        }
    }

    Component {
        id: processComponent
        Process {
            running: false
            stdout: StdioCollector {}
        }
    }

    Process {
        id: ppdProcess
        command: ["powerprofilesctl", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.ppdText = (this.text.trim() || "Unknown");
                root.powerInfoUpdated();
            }
        }
    }

    function refreshPowerInfo() {
        reader.read("/sys/firmware/acpi/platform_profile", function (data) {
            root.platformProfile = data;
            root.powerInfoUpdated();
        });

        reader.read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", function (data) {
            root.cpuGovernor = data;
            root.thermalInfoUpdated();
        });

        reader.read("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference", function (data) {
            root.energyPerformance = data;
            root.thermalInfoUpdated();
        });

        if (DetectEnv.isLaptopBattery && DetectEnv.batteryManager === "ppd") {
            ppdProcess.running = true;
        }
    }
}
