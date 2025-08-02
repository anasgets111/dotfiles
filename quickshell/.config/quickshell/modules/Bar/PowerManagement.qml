pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    property string platformInfo: "Platform: Loading..."
    property string ppdInfo: "PPD: Loading..."
    property string platformProfile: "Unknown"
    property string cpuGovernor: "Unknown"
    property string energyPerformance: "Unknown"

    property bool onBattery: UPower.onBattery

    signal powerInfoUpdated
    signal thermalInfoUpdated

    Component.onCompleted: {
        root.refreshPowerInfo();
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

    function adjustBrightness() {
        if (root.onBattery) {
            brightnessProcess.command = ["sh", "-c", "brightnessctl set 10% && brightnessctl -d asus::kbd_backlight set 1"];
        } else {
            brightnessProcess.command = ["sh", "-c", "brightnessctl set 100% && brightnessctl -d asus::kbd_backlight set 3"];
        }
        brightnessProcess.running = true;
    }

    QtObject {
        id: reader

        function read(filePath, callback) {
            var process = processComponent.createObject(root, {
                "command": ["cat", filePath]
            });

            process.stdout.streamFinished.connect(function () {
                var data = process.stdout.text.trim();
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
                root.ppdInfo = "PPD: " + (this.text.trim() || "Unknown");
                root.powerInfoUpdated();
            }
        }
    }

    function refreshPowerInfo() {
        reader.read("/sys/firmware/acpi/platform_profile", function (data) {
            root.platformProfile = data;
            root.platformInfo = "Platform: " + data;
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
