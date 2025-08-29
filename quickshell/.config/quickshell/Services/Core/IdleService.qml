pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  property alias enabled: properties.enabled

  function toggle() {
    if (properties.enabled) {
      process.signal(888);
      properties.enabled = false;
    } else {
      properties.enabled = true;
    }
  }

  PersistentProperties {
    id: properties

    property bool enabled: false

    reloadableId: "Caffeine"
  }
  Process {
    id: process

    command: ["sh", "-c", "systemd-inhibit --what=idle --who=Caffeine --why='Caffeine module is active' --mode=block sleep inf"]
    running: properties.enabled
  }
}
