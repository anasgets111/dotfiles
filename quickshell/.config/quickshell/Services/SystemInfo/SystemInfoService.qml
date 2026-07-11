pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

  property real _lastCpuIdle: 0
  property real _lastCpuTotal: 0
  property string bootDuration: ""
  property real bootTimeMs: 0
  property real cpuPerc: 0
  property real cpuTemp: 0
  property real gpuPerc: 0
  property real gpuMemTotalKib: 0
  property real gpuMemUsedKib: 0
  property real gpuTemp: 0
  property string gpuType: "NONE"
  readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0
  property real memTotal: 0
  property real memUsed: 0
  property int refCount: 0
  property var storageDisks: []
  readonly property string uptime: {
    if (bootTimeMs <= 0)
      return "";
    const elapsed = TimeService.now.getTime() - bootTimeMs;
    return (elapsed / 1000).toFixed(0);
  }

  function _pollGpuUsage(): void {
    if (root.gpuType === "NONE")
      return;
    const command = root.gpuType === "NVIDIA" ? ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"] : ["sh", "-c", "for d in /sys/class/drm/card[0-9]/device; do [ -r \"$d/gpu_busy_percent\" ] && printf 'usage ' && cat \"$d/gpu_busy_percent\"; [ -r \"$d/mem_info_vram_used\" ] && [ -r \"$d/mem_info_vram_total\" ] && printf 'memory ' && cat \"$d/mem_info_vram_used\" \"$d/mem_info_vram_total\" | tr '\\n' ' ' && printf '\\n'; done"];
    Command.run(command, result => {
      const text = result.stdout;
      if (root.gpuType === "NVIDIA") {
        const [usage, temp, memoryUsedMib, memoryTotalMib] = text.trim().split(",").map(s => parseInt(s, 10));
        if (Number.isFinite(usage)) {
          root.gpuPerc = usage / 100;
        }
        if (Number.isFinite(temp))
          root.gpuTemp = temp;
        if (Number.isFinite(memoryUsedMib) && Number.isFinite(memoryTotalMib)) {
          root.gpuMemUsedKib = memoryUsedMib * 1024;
          root.gpuMemTotalKib = memoryTotalMib * 1024;
        }
      } else if (root.gpuType === "GENERIC") {
        const usageValues = [];
        let memoryUsedBytes = 0;
        let memoryTotalBytes = 0;
        for (const line of text.trim().split("\n")) {
          const parts = line.trim().split(/\s+/);
          if (parts[0] === "usage" && Number.isFinite(Number(parts[1])))
            usageValues.push(Number(parts[1]));
          else if (parts[0] === "memory" && Number.isFinite(Number(parts[1])) && Number.isFinite(Number(parts[2]))) {
            memoryUsedBytes += Number(parts[1]);
            memoryTotalBytes += Number(parts[2]);
          }
        }
        if (usageValues.length > 0) {
          root.gpuPerc = usageValues.reduce((a, b) => a + b, 0) / usageValues.length / 100;
        }
        root.gpuMemUsedKib = memoryUsedBytes / 1024;
        root.gpuMemTotalKib = memoryTotalBytes / 1024;
      }
    }, "sysinfo.gpu");
  }

  function _pollSensors(): void {
    Command.run(["env", "LANG=C", "LC_ALL=C", "sensors"], result => {
      const text = result.stdout;
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
    }, "sysinfo.sensors");
  }

  function _pollStorage(): void {
    Command.run(["lsblk", "--json", "--bytes", "--output", "NAME,PATH,TYPE,MOUNTPOINT,FSUSED,FSAVAIL"], result => {
      try {
        const roots = JSON.parse(result.stdout || "{}").blockdevices || [];
        const disks = [];

        for (const disk of roots) {
          if (disk.type !== "disk" || disk.name?.startsWith("zram"))
            continue;
          const partitions = [];
          const collectMounted = node => {
            const usedBytes = Number(node.fsused) || 0;
            const availableBytes = Number(node.fsavail) || 0;
            const totalBytes = usedBytes + availableBytes;
            if (node.mountpoint && node.mountpoint !== "[SWAP]" && totalBytes > 0) {
              partitions.push({
                mountPoint: node.mountpoint,
                usedKib: usedBytes / 1024,
                totalKib: totalBytes / 1024,
                percentage: usedBytes / totalBytes
              });
            }
            for (const child of node.children || [])
              collectMounted(child);
          };
          collectMounted(disk);
          if (!partitions.length)
            continue;
          const diskUsedKib = partitions.reduce((sum, partition) => sum + partition.usedKib, 0);
          const diskTotalKib = partitions.reduce((sum, partition) => sum + partition.totalKib, 0);
          disks.push({
            name: disk.name,
            partitions,
            usedKib: diskUsedKib,
            totalKib: diskTotalKib
          });
        }

        root.storageDisks = disks;
      } catch (error) {
        Logger.warn("SystemInfo", `Storage parse failed: ${error}`);
      }
    }, "sysinfo.storage");
  }

  Component.onCompleted: {
    Command.run(["systemd-analyze"], result => {
      const parts = result.stdout.split("=");
      if (parts.length > 1) {
        root.bootDuration = parts[parts.length - 1].trim().split("\n")[0];
        Logger.log("SystemInfo", `Boot Time: ${root.bootDuration}`);
      }
    });
    Command.run(["sh", "-c", "command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1 && echo NVIDIA || (ls /sys/class/drm/card[0-9]/device/gpu_busy_percent 2>/dev/null | grep -q . && echo GENERIC || echo NONE)"], result => root.gpuType = result.stdout.trim());
  }
  onGpuTypeChanged: Logger.log("SystemInfo", `GPU type: ${gpuType}`)

  FileView {
    id: uptimeFile

    path: "/proc/uptime"

    onLoaded: {
      const uptimeSec = parseFloat(text().split(" ")[0] || "0");
      root.bootTimeMs = Date.now() - uptimeSec * 1000;
    }
  }

  FileView {
    id: cpuStatFile

    path: "/proc/stat"

    onLoaded: {
      const match = text().match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
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
        }
      }
      root._lastCpuTotal = total;
      root._lastCpuIdle = idle;
    }
  }

  FileView {
    id: meminfoFile

    path: "/proc/meminfo"

    onLoaded: {
      const t = text();
      const total = parseInt(t.match(/MemTotal:\s*(\d+)/)?.[1] || "0", 10);
      const avail = parseInt(t.match(/MemAvailable:\s*(\d+)/)?.[1] || "0", 10);
      if (total > 0 && avail >= 0) {
        root.memTotal = total;
        root.memUsed = total - avail;
      }
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.refCount > 0
    triggeredOnStart: true

    onTriggered: {
      cpuStatFile.reload();
      meminfoFile.reload();
      root._pollGpuUsage();
      root._pollSensors();
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: root.refCount > 0
    triggeredOnStart: true

    onTriggered: root._pollStorage()
  }
}
