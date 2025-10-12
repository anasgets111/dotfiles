pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.Services.Utils
import qs.Services.SystemInfo

Singleton {
  id: root

  // Reusable storage for df parsing
  property var _storageDevices: ({})

  // Uptime: computed from boot time, updates with TimeService clock
  property real bootTimeMs: 0
  property real cpuPerc
  // ===== Readiness flags (avoid initial zeros) =====
  property bool cpuPercReady: false
  property real cpuTemp
  property bool cpuTempReady: false
  property real gpuPerc
  property bool gpuPercReady: false
  property real gpuTemp
  property bool gpuTempReady: false
  property string gpuType: "NONE"
  property real lastCpuIdle: 0
  property real lastCpuTotal: 0
  // ===== Configuration =====
  // Enable/disable periodic snapshot logging in addition to change-driven logs
  property bool logEveryTick: true
  readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0
  property bool memReady: false
  property real memTotal
  property real memUsed
  // Main poll interval for CPU/memory/GPU (ms)
  property int pollIntervalMs: 3000
  // Enable polling by default so periodic updates/logging occur. Set to 0 to pause.
  property int refCount: 0
  property real storagePerc: storageTotal > 0 ? storageUsed / storageTotal : 0
  // Storage poll interval (ms); storage changes slowly and df is heavier
  property int storagePollIntervalMs: 60000
  property bool storageReady: false
  property real storageTotal
  property real storageUsed
  readonly property string uptime: bootTimeMs > 0 ? (((Date.now() + 0 * TimeService.now) - bootTimeMs) / 1000).toFixed(2) : ""

  function fmtKib(v) {
    const f = formatKib(v || 0);
    return f.value.toFixed(1) + " " + f.unit;
  }

  function fmtPerc(v) {
    return root.isFiniteNumber(v) ? (v * 100).toFixed(1) + "%" : "-";
  }

  function formatKib(kib: real): var {
    const mib = 1024;
    const gib = 1024 ** 2;
    const tib = 1024 ** 3;

    if (kib >= tib)
      return {
        value: kib / tib,
        unit: "TiB"
      };
    if (kib >= gib)
      return {
        value: kib / gib,
        unit: "GiB"
      };
    if (kib >= mib)
      return {
        value: kib / mib,
        unit: "MiB"
      };
    return {
      value: kib,
      unit: "KiB"
    };
  }

  // Helpers for pretty logging
  function isFiniteNumber(v) {
    return typeof v === "number" && isFinite(v);
  }

  function logMemory() {
    if (!root.memReady || !root.memTotal)
      return;
    Logger.log("SystemInfo", `Memory ${fmtKib(root.memUsed)} / ${fmtKib(root.memTotal)} (${fmtPerc(root.memPerc)})`);
  }

  function logSnapshot() {
    // CPU
    if (root.cpuPercReady && root.isFiniteNumber(cpuPerc))
      Logger.log("SystemInfo", `CPU usage ${fmtPerc(cpuPerc)}`);
    if (root.cpuTempReady && root.isFiniteNumber(cpuTemp))
      Logger.log("SystemInfo", `CPU temp ${cpuTemp.toFixed(1)} °C`);

    // Memory
    logMemory();

    // GPU
    if (root.gpuPercReady && root.isFiniteNumber(gpuPerc))
      Logger.log("SystemInfo", `GPU usage ${fmtPerc(gpuPerc)}`);
    if (root.gpuTempReady && root.isFiniteNumber(gpuTemp))
      Logger.log("SystemInfo", `GPU temp ${gpuTemp.toFixed(1)} °C`);
  }

  function logStorage() {
    if (!root.storageReady || !root.storageTotal)
      return;
    const perc = root.storageTotal > 0 ? root.storageUsed / root.storageTotal : 0;
    Logger.log("SystemInfo", `Storage ${fmtKib(root.storageUsed)} / ${fmtKib(root.storageTotal)} (${fmtPerc(perc)})`);
  }

  // Property change logging
  onCpuPercChanged: if (root.cpuPercReady && root.isFiniteNumber(cpuPerc))
    Logger.log("SystemInfo", `CPU usage ${fmtPerc(cpuPerc)}`)
  onCpuTempChanged: if (root.cpuTempReady && root.isFiniteNumber(cpuTemp))
    Logger.log("SystemInfo", `CPU temp ${cpuTemp.toFixed(1)} °C`)
  onGpuPercChanged: if (root.gpuPercReady && root.isFiniteNumber(gpuPerc))
    Logger.log("SystemInfo", `GPU usage ${fmtPerc(gpuPerc)}`)
  onGpuTempChanged: if (root.gpuTempReady && root.isFiniteNumber(gpuTemp))
    Logger.log("SystemInfo", `GPU temp ${gpuTemp.toFixed(1)} °C`)
  onGpuTypeChanged: Logger.log("SystemInfo", `GPU type ${gpuType}`)
  onMemTotalChanged: logMemory()
  onMemUsedChanged: logMemory()
  onStorageTotalChanged: logStorage()
  onStorageUsedChanged: logStorage()

  Process {
    id: bootTimeProc

    command: ["sh", "-c", "cat /proc/uptime"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const parts = text.trim().split(" ");
        const uptimeSec = parseFloat(parts[0] || "0");
        root.bootTimeMs = Date.now() - (uptimeSec * 1000);
      }
    }
  }

  // ===== Poll timers =====
  Timer {
    interval: root.pollIntervalMs
    repeat: true
    running: root.refCount > 0
    triggeredOnStart: true

    onTriggered: {
      if (root.logEveryTick)
        root.logSnapshot();
      cpuStatProc.running = true;
      meminfoProc.running = true;
      gpuUsage.running = true;
      sensors.running = true;
    }
  }

  // Poll storage less frequently; it's expensive and changes slowly
  Timer {
    interval: root.storagePollIntervalMs
    repeat: true
    running: root.refCount > 0
    triggeredOnStart: true

    onTriggered: {
      storage.running = true;
    }
  }

  // Use persistent Process instead of FileView to avoid caching
  Process {
    id: cpuStatProc

    command: ["cat", "/proc/stat"]

    stdout: StdioCollector {
      onStreamFinished: {
        const data = text.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
        if (data) {
          const stats = data.slice(1).map(n => parseInt(n, 10));
          const total = stats.reduce((a, b) => a + b, 0);
          const idle = stats[3] + (stats[4] ?? 0);

          const totalDiff = total - root.lastCpuTotal;
          const idleDiff = idle - root.lastCpuIdle;
          const nextCpuPerc = totalDiff > 0 ? (1 - idleDiff / totalDiff) : undefined;
          if (nextCpuPerc !== undefined && nextCpuPerc >= 0 && nextCpuPerc <= 1) {
            root.cpuPerc = nextCpuPerc;
            root.cpuPercReady = true;
          }

          root.lastCpuTotal = total;
          root.lastCpuIdle = idle;
        }
      }
    }
  }

  Process {
    id: meminfoProc

    command: ["cat", "/proc/meminfo"]

    stdout: StdioCollector {
      onStreamFinished: {
        const data = text;
        const totalMatch = data.match(/MemTotal: *(\d+)/);
        const availMatch = data.match(/MemAvailable: *(\d+)/);
        if (totalMatch && availMatch) {
          const total = parseInt(totalMatch[1], 10);
          const avail = parseInt(availMatch[1], 10);
          if (root.isFiniteNumber(total) && total > 0 && root.isFiniteNumber(avail)) {
            root.memTotal = total;
            const used = total - avail;
            if (root.isFiniteNumber(used) && used >= 0) {
              root.memUsed = used;
              root.memReady = true;
            }
          }
        }
      }
    }
  }

  Process {
    id: storage

    command: ["sh", "-c", "df | grep '^/dev/' | awk '{print $1, $3, $4}'"]

    stdout: StdioCollector {
      onStreamFinished: {
        const prevUsed = root.storageUsed;
        const prevTotal = root.storageTotal;

        // Reuse object instead of creating new Map
        const deviceMap = root._storageDevices;
        for (const key in deviceMap)
          delete deviceMap[key];

        for (const line of text.trim().split("\n")) {
          if (!line.trim())
            continue;

          const parts = line.trim().split(/\s+/);
          if (parts.length >= 3) {
            const device = parts[0];
            const used = parseInt(parts[1], 10) || 0;
            const avail = parseInt(parts[2], 10) || 0;

            // Only keep the entry with the largest total space for each device
            const existing = deviceMap[device];
            if (!existing || (used + avail) > (existing.used + existing.avail)) {
              deviceMap[device] = {
                used,
                avail
              };
            }
          }
        }

        let totalUsed = 0;
        let totalAvail = 0;

        for (const device in deviceMap) {
          const stats = deviceMap[device];
          totalUsed += stats.used;
          totalAvail += stats.avail;
        }

        const newUsed = totalUsed;
        const newTotal = totalUsed + totalAvail;

        if (!root.storageReady)
          root.storageReady = true;
        root.storageUsed = newUsed;
        root.storageTotal = newTotal;

        // If nothing changed, still emit a log so the drive shows up periodically
        if (prevUsed === newUsed && prevTotal === newTotal)
          root.logStorage();
      }
    }
  }

  Process {
    id: gpuTypeCheck

    command: ["sh", "-c", "if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then echo NVIDIA; elif ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | grep -q .; then echo GENERIC; else echo NONE; fi"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: root.gpuType = text.trim()
    }
  }

  Process {
    id: gpuUsage

    command: root.gpuType === "GENERIC" ? ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent"] : root.gpuType === "NVIDIA" ? ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"] : ["echo"]

    stdout: StdioCollector {
      onStreamFinished: {
        if (root.gpuType === "GENERIC") {
          const values = text.trim().split("\n").map(s => parseInt(s, 10)).filter(n => root.isFiniteNumber(n));
          if (values.length > 0) {
            const sum = values.reduce((a, b) => a + b, 0);
            const perc = sum / values.length / 100;
            if (root.isFiniteNumber(perc)) {
              root.gpuPerc = perc;
              root.gpuPercReady = true;
            }
          }
        } else if (root.gpuType === "NVIDIA") {
          const parts = text.trim().split(",");
          if (parts.length >= 2) {
            const usageVal = parseInt(parts[0], 10);
            const tempVal = parseInt(parts[1], 10);
            if (root.isFiniteNumber(usageVal)) {
              root.gpuPerc = usageVal / 100;
              root.gpuPercReady = true;
            }
            if (root.isFiniteNumber(tempVal)) {
              root.gpuTemp = tempVal;
              root.gpuTempReady = true;
            }
          }
        }
        // else: leave previous values; do not force zeros
      }
    }
  }

  Process {
    id: sensors

    command: ["env", "LANG=C", "LC_ALL=C", "sensors"]

    stdout: StdioCollector {
      onStreamFinished: {
        // Prefer Package id/Tdie; fall back to Tctl if not found
        const cpuTemp = text.match(/(?:Package id [0-9]+|Tdie):\s+((\+|-)[0-9.]+)(°| )C/) || text.match(/Tctl:\s+((\+|-)[0-9.]+)(°| )C/);

        if (cpuTemp) {
          const t = parseFloat(cpuTemp[1]);
          if (root.isFiniteNumber(t)) {
            root.cpuTemp = t;
            root.cpuTempReady = true;
          }
        }

        if (root.gpuType !== "GENERIC")
          return;

        let eligible = false;
        let sum = 0;
        let count = 0;

        for (const line of text.trim().split("\n")) {
          if (line === "Adapter: PCI adapter")
            eligible = true;
          else if (line === "")
            eligible = false;
          else if (eligible) {
            let match = line.match(/^(temp[0-9]+|GPU core|edge)+:\s+\+([0-9]+\.[0-9]+)(°| )C/);
            if (!match)
              // Fall back to junction/mem if GPU doesn't have edge temp (for AMD GPUs)
              match = line.match(/^(junction|mem)+:\s+\+([0-9]+\.[0-9]+)(°| )C/);

            if (match) {
              sum += parseFloat(match[2]);
              count++;
            }
          }
        }

        if (count > 0) {
          const t = sum / count;
          if (root.isFiniteNumber(t)) {
            root.gpuTemp = t;
            root.gpuTempReady = true;
          }
        }
      }
    }
  }
}
