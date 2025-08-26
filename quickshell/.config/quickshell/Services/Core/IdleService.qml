pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {

    property alias enabled: properties.enabled

    PersistentProperties {
        id: properties
        reloadableId: "Caffeine"

        property bool enabled: false
    }

    function toggle() {
        if (properties.enabled) {
            process.signal(888);
            properties.enabled = false;
        } else {
            properties.enabled = true;
        }
    }

    Process {
        id: process
        running: properties.enabled
        command: ["sh", "-c", "systemd-inhibit --what=idle --who=Caffeine --why='Caffeine module is active' --mode=block sleep inf"]
    }
}
