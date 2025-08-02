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
    }

    // Reusable file reader component
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

    // PPD process (still needed for specific powerprofilesctl command)
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

    // Function to refresh all power information
    function refreshPowerInfo() {
        // Read platform profile
        reader.read("/sys/firmware/acpi/platform_profile", function (data) {
            root.platformProfile = data;
            root.platformInfo = "Platform: " + data;
            root.powerInfoUpdated();
        });

        // Read CPU governor
        reader.read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", function (data) {
            root.cpuGovernor = data;
            root.thermalInfoUpdated();
        });

        // Read energy performance preference
        reader.read("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference", function (data) {
            root.energyPerformance = data;
            root.thermalInfoUpdated();
        });

        // Only fetch PPD info if using PPD
        if (DetectEnv.isLaptopBattery && DetectEnv.batteryManager === "ppd") {
            ppdProcess.running = true;
        }
    }
}
