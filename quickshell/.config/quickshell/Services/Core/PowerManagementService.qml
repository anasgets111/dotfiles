pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils

// Unifies power profile backends (power-profiles-daemon, TLP) and later brightness control
Singleton {
  id: pms

  // For future: brightness passthrough to dedicated services
  // property alias screenBrightness: BrightnessService.level
  // property alias keyboardBrightness: KeyboardBacklightService.level

  // Private
  property string _detectedBackend: "none"

  // Backend detection
  readonly property string backend: pms._detectedBackend

  // Normalized profile: "performance" | "balanced" | "powersave"
  property string currentProfile: "balanced"
  readonly property bool hasPerformance: backend === "ppd" || backend === "tlp"
  readonly property bool isReady: backend !== "none"

  // Map backend string to normalized profile string
  function _normalizeProfile(b, raw) {
    const v = String(raw || "").toLowerCase();
    if (b === "ppd") {
      if (v.indexOf("performance") !== -1)
        return "performance";
      if (v.indexOf("power-saver") !== -1)
        return "powersave";
      return "balanced";
    } else if (b === "tlp") {
      if (v.indexOf("performance") !== -1)
        return "performance";
      if (v.indexOf("powersave") !== -1)
        return "powersave";
      return "balanced";
    }
    return "balanced";
  }
  function refresh() {
    detectProc.running = true;
  }

  // Normalized setter; maps to backend-specific commands
  function setProfile(mode) {
    var m = String(mode || "").toLowerCase();
    if (["performance", "balanced", "powersave"].indexOf(m) === -1)
      m = "balanced";

    if (backend === "ppd") {
      // powerprofilesctl set perf|balanced|power-saver
      const arg = (m === "performance") ? "performance" : (m === "powersave" ? "power-saver" : "balanced");
      setProc.command = ["sh", "-lc", `powerprofilesctl set ${arg}`];
      setProc.running = true;
    } else if (backend === "tlp") {
      // sudo tlp setprofile PERFORMANCE|BALANCED|POWERSAVE (may require sudoers without password)
      const arg = (m === "performance") ? "PERFORMANCE" : (m === "powersave" ? "POWERSAVE" : "BALANCED");
      setProc.command = ["sh", "-lc", `tlp setprofile ${arg}`];
      setProc.running = true;
    }
  }

  // === Detection and querying ===
  Process {
    id: detectProc

    command: ["sh", "-lc", "if command -v powerprofilesctl >/dev/null 2>&1; then echo ppd; elif command -v tlp >/dev/null 2>&1; then echo tlp; else echo none; fi"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const b = text.trim();
        pms._detectedBackend = (b === "ppd" || b === "tlp") ? b : "none";
        if (pms._detectedBackend === "ppd") {
          queryProc.command = ["sh", "-lc", "powerprofilesctl get || true"];
          queryProc.running = true;
        } else if (pms._detectedBackend === "tlp") {
          // tlp-stat -b prints Active profile: performance/balanced/powersave etc.
          queryProc.command = ["sh", "-lc", "tlp-stat -b 2>/dev/null | sed -n 's/^\s*Active profile:\s*//p' | head -n1"];
          queryProc.running = true;
        } else {
          pms.currentProfile = "balanced";
        }
      }
    }
  }
  Process {
    id: queryProc

    command: ["sh", "-lc", "echo balanced"]

    stdout: StdioCollector {
      onStreamFinished: pms.currentProfile = pms._normalizeProfile(pms.backend, text.trim())
    }
  }
  Process {
    id: setProc

    command: ["sh", "-lc", "true"]

    stdout: StdioCollector {
      onStreamFinished: {
        // Re-query after setting
        if (pms.backend === "ppd") {
          queryProc.command = ["sh", "-lc", "powerprofilesctl get || true"];
        } else if (pms.backend === "tlp") {
          queryProc.command = ["sh", "-lc", "tlp-stat -b 2>/dev/null | sed -n 's/^\s*Active profile:\s*//p' | head -n1"];
        }
        queryProc.running = true;
      }
    }
  }
}
