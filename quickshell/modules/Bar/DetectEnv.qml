pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root

    property string sessionName: ""
    readonly property string session: sessionName.toLowerCase().split(":")[0]
    property bool isHyprland: session === "hyprland"
    property bool isNiri: session === "niri"
    property string distroId: ""
    property var upowerDevice: UPower.displayDevice
    readonly property bool isLaptopBattery: upowerDevice && upowerDevice.type === 2 && upowerDevice.isPresent

    Component.onCompleted: {
        sessionName = Quickshell.env("XDG_SESSION_DESKTOP") || Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("DESKTOP_SESSION") || "";
    }

    FileView {
        id: osReleaseFile

        path: "/etc/os-release"
        blockLoading: true
        preload: true
        onLoaded: {
            var idMatch = osReleaseFile.text().match(/^ID="?([^"\n]+)"?/m);
            root.distroId = idMatch ? idMatch[1] : "";
        }
    }
}
