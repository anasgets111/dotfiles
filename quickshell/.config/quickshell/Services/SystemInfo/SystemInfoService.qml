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
  property real gpuMemTotalKib: 0
  property real gpuMemUsedKib: 0
  property real gpuPerc: 0
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

  function _clearGpuSnapshot(): void {
    gpuType = "NONE";
    gpuPerc = 0;
    gpuTemp = 0;
    gpuMemUsedKib = 0;
    gpuMemTotalKib = 0;
  }
  function _pollGpuUsage(): void {
    Command.run(["nvtop", "-s"], result => {
      try {
        // ponytail: the widget shows one GPU; add a selector before supporting multi-GPU hosts.
        const gpu = JSON.parse(result.stdout)?.[0];
        if (!gpu) {
          root._clearGpuSnapshot();
          return;
        }
        root.gpuType = gpu.device_name || "GPU";
        root.gpuPerc = Math.min((parseFloat(gpu.gpu_util) || 0) / 100, 1);
        root.gpuTemp = parseFloat(gpu.temp) || 0;
        root.gpuMemUsedKib = Number(gpu.mem_used) / 1024 || 0;
        root.gpuMemTotalKib = root.gpuMemUsedKib > 0 ? Number(gpu.mem_total) / 1024 || 0 : 0;
      } catch (error) {
        root._clearGpuSnapshot();
        Logger.warn("SystemInfo", `GPU parse failed: ${error}`);
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
