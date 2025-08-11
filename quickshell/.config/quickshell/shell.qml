//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import QtQuick
import Quickshell.Wayland
import "./services" as Services

ShellRoot {
    id: root

    property var main: Services.MainService
    property var wallpaper: Services.WallpaperService
    property var dateTime: Services.TimeService
    property var battery: Services.BatteryService

    // Render wallpapers only when ready
    Variants {
        model: root.wallpaper.wallpapersArray

        WlrLayershell {
            id: layerShell
            required property var modelData

            screen: {
                const scr = Quickshell.screens.find(s => s.name === layerShell.modelData.name);
                return scr || null;
            }
            layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Image {
                anchors.fill: parent
                source: layerShell.modelData.wallpaper
                fillMode: {
                    switch (layerShell.modelData.mode) {
                    case "fill":
                        return Image.PreserveAspectCrop;
                    case "fit":
                        return Image.PreserveAspectFit;
                    case "stretch":
                        return Image.Stretch;
                    case "center":
                        return Image.Pad;
                    case "tile":
                        return Image.Tile;
                    default:
                        return Image.PreserveAspectCrop;
                    }
                }
            }
        }
    }

    // Log when MainService is ready
    Connections {
        target: root.main
        function onReadyChanged() {
            if (root.main.ready) {
                console.log("=== MainService Ready ===");
                console.log("isArchBased:", root.main.isArchBased);
                console.log("currentWM:", root.main.currentWM);
                console.log("hasBrightnessControl:", root.main.hasBrightnessControl);
                console.log("hasKeyboardBacklight:", root.main.hasKeyboardBacklight);
                console.log("userInfo:", JSON.stringify({
                    username: root.main.username,
                    fullName: root.main.fullName,
                    hostname: root.main.hostname,
                    uptime: root.dateTime.formatDuration(root.main.uptime)
                }));
            }
        }
    }

    // === WallpaperService logging ===
    Connections {
        target: root.wallpaper
        function onReadyChanged() {
            if (root.wallpaper.ready) {
                console.log("=== WallpaperService Ready ===");
            }
        }
    }

    // === DateTimeService logging ===
    Connections {
        target: root.dateTime
        function onReadyChanged() {
            if (root.dateTime.ready) {
                console.log("=== DateTimeService Ready ===");
                console.log("Current Date/Time:", root.dateTime.formattedDateTime);
                console.log("Time Zone:", root.dateTime.timeZone);
                console.log("Week Start:", root.dateTime.weekStart);
                console.log("NTP Enabled:", root.dateTime.ntpEnabled);
            }
        }
    }

    // === BatteryService logging ===
    Connections {
        target: root.battery
        function onReadyChanged() {
            if (root.battery.ready) {
                console.log("=== BatteryService Ready ===");
                console.log("Is Laptop Battery:", root.battery.isLaptopBattery);
                console.log("Percentage:", Math.round(root.battery.percentage) + "%");
                console.log("Is Charging:", root.battery.isCharging);
                console.log("Is Plugged In:", root.battery.isPluggedIn);
                console.log("Low Battery:", root.battery.isLowAndNotCharging);
                console.log("Critical Battery:", root.battery.isCriticalAndNotCharging);
                console.log("Suspending Battery:", root.battery.isSuspendingAndNotCharging);
                console.log("Time to Full:", root.battery.timeToFullText);
                console.log("Time to Empty:", root.battery.timeToEmptyText);
            }
        }
    }

    // === Hot reload immediate logs ===
    Component.onCompleted: {
        if (main.ready) {
            console.log("=== MainService Already Ready ===");
            console.log("isArchBased:", main.isArchBased);
            console.log("currentWM:", main.currentWM);
            console.log("hasBrightnessControl:", main.hasBrightnessControl);
            console.log("hasKeyboardBacklight:", main.hasKeyboardBacklight);
        }
        if (wallpaper.ready) {
            console.log("=== WallpaperService Already Ready ===");
            console.log("Wallpapers:", wallpaper.wallpapers.length);
        }
        if (dateTime.ready) {
            console.log("=== DateTimeService Already Ready ===");
            console.log("Current Date/Time:", dateTime.formattedDateTime);
            console.log("Time Zone:", dateTime.timeZone);
            console.log("Week Start:", dateTime.weekStart);
            console.log("NTP Enabled:", dateTime.ntpEnabled);
            if (dateTime.isReady && !dateTime.ntpEnabled) {
                dateTime.setNtpEnabled(true); // enable NTP
            }
        }
        if (battery.ready) {
            console.log("=== BatteryService Already Ready ===");
            console.log("Is Laptop Battery:", battery.isLaptopBattery);
            console.log("Percentage:", Math.round(battery.percentage) + "%");
            console.log("Is Charging:", battery.isCharging);
            console.log("Is Plugged In:", battery.isPluggedIn);
            console.log("Low Battery:", battery.isLowAndNotCharging);
            console.log("Critical Battery:", battery.isCriticalAndNotCharging);
            console.log("Suspending Battery:", battery.isSuspendingAndNotCharging);
            console.log("Time to Full:", battery.timeToFullText);
            console.log("Time to Empty:", battery.timeToEmptyText);
        }
    }
}
