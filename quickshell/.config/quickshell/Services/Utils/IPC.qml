pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Services.Core
import qs.Services.SystemInfo

// Centralized IPC handlers. Each target delegates to its service singleton.
// This consolidates scattered IpcHandler blocks from services/components.
Singleton {
  id: ipc

  // ----- Lock -----
  IpcHandler {
    function islocked(): string {
      return LockService.locked ? "true" : "false";
    }
    function lock(): string {
      Logger.log("IPC", "lock");
      LockService.locked = true;
      return "locked";
    }
    function status(): string {
      const s = LockService.locked ? "locked" : "unlocked";
      Logger.log("IPC", `status -> ${s}`);
      return s;
    }
    function toggle(): string {
      Logger.log("IPC", "toggle");
      LockService.locked = !LockService.locked;
      return LockService.locked ? "locked" : "unlocked";
    }
    function unlock(): string {
      Logger.log("IPC", "unlock");
      LockService.locked = false;
      return "unlocked";
    }

    target: "lock"
  }

  // ----- Audio -----
  IpcHandler {
    function decrement(step: string): string {
      if (AudioService.sink && AudioService.sink.audio) {
        if (AudioService.sink.audio.muted)
          AudioService.sink.audio.muted = false;
        const current = Math.round(AudioService.sink.audio.volume * 100);
        const parsed = Number.parseInt(step ?? "5", 10);
        const delta = Number.isNaN(parsed) ? 5 : parsed;
        const newVolume = Math.max(0, Math.min(AudioService.maxVolumePercent, current - delta));
        AudioService.sink.audio.volume = newVolume / 100;
        Logger.log("IPC", "decrement", delta, "->", newVolume + "%");
        return "Volume decreased to " + newVolume + "%";
      }
      return "No audio sink available";
    }
    function increment(step: string): string {
      // emulate previous behavior using AudioService API
      if (AudioService.sink && AudioService.sink.audio) {
        if (AudioService.sink.audio.muted)
          AudioService.sink.audio.muted = false;
        const current = Math.round(AudioService.sink.audio.volume * 100);
        const parsed = Number.parseInt(step ?? "5", 10);
        const delta = Number.isNaN(parsed) ? 5 : parsed;
        const newVolume = Math.max(0, Math.min(AudioService.maxVolumePercent, current + delta));
        AudioService.sink.audio.volume = newVolume / 100;
        Logger.log("IPC", "increment", delta, "->", newVolume + "%");
        return "Volume increased to " + newVolume + "%";
      }
      return "No audio sink available";
    }
    function micmute(): string {
      Logger.log("IPC", "micmute");
      return AudioService.toggleMicMute();
    }
    function mute(): string {
      Logger.log("IPC", "mute");
      return AudioService.toggleMute();
    }
    function setmic(percentage: string): string {
      Logger.log("IPC", "setmic", percentage);
      return AudioService.setMicVolume(percentage);
    }
    function setvolume(percentage: string): string {
      Logger.log("IPC", "setvolume", percentage);
      return AudioService.setVolume(percentage);
    }
    function status(): string {
      let result = "Audio Status:\n";
      if (AudioService.sink && AudioService.sink.audio) {
        const volume = Math.round(AudioService.sink.audio.volume * 100);
        result += "Output: " + volume + "%" + (AudioService.sink.audio.muted ? " (muted)" : "") + "\n";
      } else {
        result += "Output: No sink available\n";
      }
      if (AudioService.source && AudioService.source.audio) {
        const micVolume = Math.round(AudioService.source.audio.volume * 100);
        result += "Input: " + micVolume + "%" + (AudioService.source.audio.muted ? " (muted)" : "");
      } else {
        result += "Input: No source available";
      }
      return result;
    }

    target: "audio"
  }

  // ----- OSD -----
  IpcHandler {
    function clear(): string {
      OSDService.clearQueue();
      return "cleared";
    }
    function dnd(state: string): string {
      if (typeof state === "string")
        OSDService.setDoNotDisturb(state.toLowerCase() === "on" || state.toLowerCase() === "true");
      else
        OSDService.setDoNotDisturb(!!state);
      return "DND=" + OSDService.doNotDisturb;
    }
    function error(message: string): string {
      OSDService.showError(message, "");
      return "ok";
    }
    function errord(message: string, details: string): string {
      OSDService.showError(message, details);
      return "ok";
    }
    function hide(): string {
      OSDService.hideToast();
      return "hidden";
    }
    function info(message: string): string {
      OSDService.showInfo(message, "");
      return "ok";
    }
    function infod(message: string, details: string): string {
      OSDService.showInfo(message, details);
      return "ok";
    }
    function showlvl(message: string, level: int): string {
      OSDService.showToast(message, level, "");
      return "ok";
    }
    function showlvld(message: string, level: int, details: string): string {
      OSDService.showToast(message, level, details);
      return "ok";
    }
    function status(): string {
      return `OSD: visible=${OSDService.toastVisible}, queued=${OSDService.toastQueue.length}, level=${OSDService.currentLevel}, repeats=${OSDService.currentRepeatCount}, DND=${OSDService.doNotDisturb}`;
    }
    function warn(message: string): string {
      OSDService.showWarning(message, "");
      return "ok";
    }
    function warnd(message: string, details: string): string {
      OSDService.showWarning(message, details);
      return "ok";
    }

    target: "osd"
  }

  // ----- Notifications -----
  IpcHandler {
    function clear(): string {
      NotificationService.dismissAllActive();
      return "Active notifications dismissed";
    }
    function clearhistory(): string {
      NotificationService.clearHistory();
      return "History cleared";
    }
    function send(summary: string, body: string, optionsJson: string): string {
      // Sending via IPC is not wired directly to NotificationServer in this build.
      // Use: notify-send 'summary' 'body' from shell, or integrate a small bridge if needed.
      return "send-not-implemented";
    }
    function status(): string {
      const dnd = NotificationService.dndPolicy ? (NotificationService.dndPolicy.enabled ? "on" : "off") : "off";
      const behavior = NotificationService.dndPolicy && NotificationService.dndPolicy.behavior ? NotificationService.dndPolicy.behavior : "queue";
      const groupsCount = (NotificationService.groups && typeof NotificationService.groups === "function") ? NotificationService.groups().length : 0;
      const historyCount = NotificationService.historyModel ? NotificationService.historyModel.count : 0;
      const activeCount = (NotificationService.activeCount !== undefined) ? NotificationService.activeCount : 0;
      const visibleCount = NotificationService.visibleModel ? NotificationService.visibleModel.count : 0;
      const maxVisible = (NotificationService.maxVisibleNotifications !== undefined) ? NotificationService.maxVisibleNotifications : 0;
      return `Notifications: active=${activeCount}, visible=${visibleCount}, history=${historyCount}, groups=${groupsCount}, dnd=${dnd}(${behavior}), maxVisible=${maxVisible}`;
    }
    function debug(): string {
      // Compact snapshot of potentially growing structures for triage
      const hist = NotificationService.historyModel ? NotificationService.historyModel.count : 0;
      const vis = NotificationService.visibleModel ? NotificationService.visibleModel.count : 0;
      const groupsCount = (NotificationService.groups && typeof NotificationService.groups === "function") ? NotificationService.groups().length : 0;
      const wpNames = WallpaperService && WallpaperService.prefsByName ? Object.keys(WallpaperService.prefsByName) : [];
      const wpTimers = WallpaperService && WallpaperService.timersByName ? Object.keys(WallpaperService.timersByName) : [];
      const netIfs = NetworkService && NetworkService.deviceList ? (NetworkService.deviceList || []).length : 0;
      const wifiAps = NetworkService && NetworkService.wifiAps ? (NetworkService.wifiAps || []).length : 0;
      return [`notif{hist=${hist}, vis=${vis}, groups=${groupsCount}}`, `wp{names=${wpNames.length}, timers=${wpTimers.length}}`, `net{dev=${netIfs}, aps=${wifiAps}}`].join(" ");
    }

    target: "notifs"
  }

  // ----- Media (MPRIS) -----
  IpcHandler {
    function getActive(prop: string): string {
      const a = MediaService.active;
      if (!a)
        return "No active player";
      const v = a[prop];
      return (v === undefined) ? "Invalid property" : String(v);
    }
    function list(): string {
      return MediaService.players.map(p => p.identity).join("\n");
    }
    function next(): void {
      MediaService.next();
    }
    function pause(): void {
      MediaService.pause();
    }
    function play(): void {
      MediaService.play();
    }
    function playPause(): void {
      MediaService.playPause();
    }
    function previous(): void {
      MediaService.previous();
    }
    function seek(position: real): void {
      MediaService.seek(position);
    }
    function seekByRatio(ratio: real): void {
      MediaService.seekByRatio(ratio);
    }
    function stop(): void {
      MediaService.stop();
    }

    target: "mpris"
  }

  // ----- Screen Recording -----
  IpcHandler {
    function toggle(): string {
      Logger.log("IPC", "rec.toggle");
      ScreenRecordingService.toggleRecording();
      return ScreenRecordingService.isRecording ? "recording" : "stopped";
    }

    target: "rec"
  }
}
