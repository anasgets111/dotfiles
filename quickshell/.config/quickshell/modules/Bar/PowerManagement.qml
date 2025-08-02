pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    property string tlpInfo: "TLP: Loading..."
    property string ppdInfo: "PPD: Loading..."
    property string platformProfile: "Unknown"
    property string cpuGovernor: "Unknown"
    property string energyPerformance: "Unknown"
    
    property bool onBattery: UPower.onBattery
    
    signal powerInfoUpdated()
    signal thermalInfoUpdated()
    
    Component.onCompleted: {
        refreshPowerInfo();
    }
    
    Connections {
        target: DetectEnv
        function onBatteryManagerChanged() {
            refreshPowerInfo();
        }
    }
    
    onOnBatteryChanged: {
        refreshPowerInfo();
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

    Process {
        id: platformProfileProcess
        command: ["cat", "/sys/firmware/acpi/platform_profile"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.platformProfile = this.text.trim();
                root.tlpInfo = "Platform: " + root.platformProfile;
                root.powerInfoUpdated();
            }
        }
    }

    Process {
        id: cpuGovernorProcess
        command: ["cat", "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuGovernor = this.text.trim();
                root.thermalInfoUpdated();
            }
        }
    }

    // Direct sysfs fetch for energy performance preference (first CPU)
    Process {
        id: energyPerformanceProcess
        command: ["cat", "/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.energyPerformance = this.text.trim();
                root.thermalInfoUpdated();
            }
        }
    }

    // Function to refresh all power information
    function refreshPowerInfo() {
        platformProfileProcess.running = true;
        cpuGovernorProcess.running = true;
        energyPerformanceProcess.running = true;
        
        // Only fetch PPD info if using PPD
        if (DetectEnv.isLaptopBattery && DetectEnv.batteryManager === "ppd") {
            ppdProcess.running = true;
        }
    }
}
