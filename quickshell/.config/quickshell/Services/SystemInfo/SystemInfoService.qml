pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.Services.Utils
import qs.Services.SystemInfo

Singleton {
  id: root

  property bool _cpuReady: false
  property bool _gpuReady: false
  property real _lastCpuIdle: 0
  property real _lastCpuTotal: 0
  property bool _memReady: false
  property bool _storageReady: false
  property string bootDuration: ""
  property real bootTimeMs: 0
  property real cpuPerc: 0
  property real cpuTemp: 0
  property real gpuPerc: 0
  property real gpuTemp: 0
  property string gpuType: "NONE"
  readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0
  property real memTotal: 0
  property real memUsed: 0
  property int pollIntervalMs: 3000
  readonly property bool ready: _cpuReady && _memReady
  property int refCount: 0
  readonly property real storagePerc: storageTotal > 0 ? storageUsed / storageTotal : 0
  property int storagePollIntervalMs: 60000
  property real storageTotal: 0
  property real storageUsed: 0
  readonly property string uptime: {
    if (bootTimeMs <= 0)
      return "";
    const elapsed = TimeService.now.getTime() - bootTimeMs;
    return (elapsed / 1000).toFixed(0);
  }

  function fmtKib(v: real): string {
    const f = formatKib(v || 0);
    return `${f.value.toFixed(1)} ${f.unit}`;
  }

  function fmtPerc(v: real): string {
    return Number.isFinite(v) ? `${(v * 100).toFixed(1)}%` : "-";
  }

  function formatKib(kib: real): var {
    const units = [
      {
        threshold: 1024 ** 3,
        unit: "TiB"
      },
      {
        threshold: 1024 ** 2,
        unit: "GiB"
      },
      {
        threshold: 1024,
        unit: "MiB"
      },
      {
        threshold: 0,
        unit: "KiB"
      }
    ];
    for (const u of units) {
      if (kib >= u.threshold)
        return {
          value: u.threshold > 0 ? kib / u.threshold : kib,
          unit: u.unit
        };
    }
    return {
      value: kib,
      unit: "KiB"
    };
  }

  function logSnapshot() {
    if (_cpuReady) {
      Logger.log("SystemInfo", `CPU: ${fmtPerc(cpuPerc)}${cpuTemp > 0 ? ` @ ${cpuTemp.toFixed(1)}°C` : ""}`);
    }
    if (_memReady && memTotal > 0) {
      Logger.log("SystemInfo", `Memory: ${fmtKib(memUsed)} / ${fmtKib(memTotal)} (${fmtPerc(memPerc)})`);
    }
    if (_gpuReady) {
      Logger.log("SystemInfo", `GPU: ${fmtPerc(gpuPerc)}${gpuTemp > 0 ? ` @ ${gpuTemp.toFixed(1)}°C` : ""}`);
    }
    if (_storageReady && storageTotal > 0) {
      Logger.log("SystemInfo", `Storage: ${fmtKib(storageUsed)} / ${fmtKib(storageTotal)} (${fmtPerc(storagePerc)})`);
    }
  }

  onGpuTypeChanged: Logger.log("SystemInfo", `GPU type: ${gpuType}`)

  Process {
    id: bootTimeProc

    command: ["cat", "/proc/uptime"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const uptimeSec = parseFloat(text.split(" ")[0] || "0");
        root.bootTimeMs = Date.now() - uptimeSec * 1000;
      }
    }
  }

  Process {
    id: bootAnalyzeProc

    command: ["systemd-analyze"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const parts = text.split("=");
        if (parts.length > 1) {
          root.bootDuration = parts[parts.length - 1].trim().split("\n")[0];
          Logger.log("SystemInfo", `Boot Time: ${root.bootDuration}`);
        }
      }
    }
  }

  Process {
    id: gpuTypeCheck

    command: ["sh", "-c", "command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1 && echo NVIDIA || (ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | grep -q . && echo GENERIC || echo NONE)"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: root.gpuType = text.trim()
    }
  }

  Timer {
    interval: root.pollIntervalMs
    repeat: true
    running: root.refCount > 0
    triggeredOnStart: true

    onTriggered: {
      cpuStatProc.running = true;
      meminfoProc.running = true;
      gpuUsageProc.running = true;
      sensorsProc.running = true;
      root.logSnapshot();
    }
  }

  Timer {
    interval: root.storagePollIntervalMs
    repeat: true
    running: root.refCount > 0
    triggeredOnStart: true

    onTriggered: storageProc.running = true
  }

  Process {
    id: cpuStatProc

    command: ["cat", "/proc/stat"]

    stdout: StdioCollector {
      onStreamFinished: {
        const match = text.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
        if (!match)
          return;

        const stats = match.slice(1).map(Number);
        const total = stats.reduce((a, b) => a + b, 0);
        const idle = stats[3] + (stats[4] || 0);
        const totalDiff = total - root._lastCpuTotal;
        const idleDiff = idle - root._lastCpuIdle;

        if (totalDiff > 0) {
          const perc = 1 - idleDiff / totalDiff;
          if (perc >= 0 && perc <= 1) {
            root.cpuPerc = perc;
            root._cpuReady = true;
          }
        }
        root._lastCpuTotal = total;
        root._lastCpuIdle = idle;
      }
    }
  }

  Process {
    id: meminfoProc

    command: ["cat", "/proc/meminfo"]

    stdout: StdioCollector {
      onStreamFinished: {
        const total = parseInt(text.match(/MemTotal:\s*(\d+)/)?.[1] || "0", 10);
        const avail = parseInt(text.match(/MemAvailable:\s*(\d+)/)?.[1] || "0", 10);
        if (total > 0 && avail >= 0) {
          root.memTotal = total;
          root.memUsed = total - avail;
          root._memReady = true;
        }
      }
    }
  }

  Process {
    id: storageProc

    command: ["sh", "-c", "df -P 2>/dev/null | awk '/^\\/dev/ {u[$1]=$3; a[$1]=$4} END {for(d in u) print d, u[d], a[d]}'"]

    stdout: StdioCollector {
      onStreamFinished: {
        let totalUsed = 0, totalAvail = 0;
        for (const line of text.trim().split("\n")) {
          const [, used, avail] = line.split(/\s+/);
          totalUsed += parseInt(used, 10) || 0;
          totalAvail += parseInt(avail, 10) || 0;
        }
        root.storageUsed = totalUsed;
        root.storageTotal = totalUsed + totalAvail;
        root._storageReady = true;
      }
    }
  }

  Process {
    id: gpuUsageProc

    command: root.gpuType === "NVIDIA" ? ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"] : root.gpuType === "GENERIC" ? ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null"] : ["true"]

    stdout: StdioCollector {
      onStreamFinished: {
        if (root.gpuType === "NVIDIA") {
          const [usage, temp] = text.trim().split(",").map(s => parseInt(s, 10));
          if (Number.isFinite(usage)) {
            root.gpuPerc = usage / 100;
            root._gpuReady = true;
          }
          if (Number.isFinite(temp))
            root.gpuTemp = temp;
        } else if (root.gpuType === "GENERIC") {
          const values = text.trim().split("\n").map(Number).filter(Number.isFinite);
          if (values.length > 0) {
            root.gpuPerc = values.reduce((a, b) => a + b, 0) / values.length / 100;
            root._gpuReady = true;
          }
        }
      }
    }
  }

  Process {
    id: sensorsProc

    command: ["env", "LANG=C", "LC_ALL=C", "sensors"]

    stdout: StdioCollector {
      onStreamFinished: {
        const cpuMatch = text.match(/(?:Package id \d+|Tdie):\s+([+-]?\d+\.?\d*).C/) || text.match(/Tctl:\s+([+-]?\d+\.?\d*).C/);
        if (cpuMatch) {
          const t = parseFloat(cpuMatch[1]);
          if (Number.isFinite(t))
            root.cpuTemp = t;
        }

        if (root.gpuType !== "GENERIC")
          return;

        let inPci = false, sum = 0, count = 0;
        for (const line of text.split("\n")) {
          if (line === "Adapter: PCI adapter")
            inPci = true;
          else if (line === "")
            inPci = false;
          else if (inPci) {
            const match = line.match(/^(?:temp\d+|GPU core|edge|junction|mem):\s+\+(\d+\.?\d*).C/);
            if (match) {
              sum += parseFloat(match[1]);
              count++;
            }
          }
        }
        if (count > 0)
          root.gpuTemp = sum / count;
      }
    }
  }
}
