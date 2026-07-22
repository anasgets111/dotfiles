pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.UI
import qs.Services.WM

Singleton {
  id: ipc

  signal launcherCloseRequested

  function toggleLauncher(): bool {
    if (ShellUiState.activeModal === "launcher") {
      ipc.launcherCloseRequested();
      return false;
    }
    ShellUiState.openModal("launcher", MonitorService.effectiveMainScreen?.name ?? "");
    return true;
  }

  IpcHandler {
    function islocked(): bool {
      return LockService.locked;
    }
    function lock(): string {
      Logger.log("IPC", "lock");
      LockService.requestLock();
      return "locked";
    }
    function status(): bool {
      Logger.log("IPC", `status -> ${LockService.locked}`);
      return LockService.locked;
    }
    function unlock(): string {
      Logger.log("IPC", "unlock");
      LockService.requestUnlock();
      return LockService.locked ? "unlocking" : "unlocked";
    }

    target: "lock"
  }
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
  IpcHandler {
    function toggle(): string {
      Logger.log("IPC", "rec.toggle");
      ScreenRecordingService.toggleRecording();
      return ScreenRecordingService.isRecording ? "recording" : ScreenRecordingService.starting ? "starting" : "stopped";
    }

    target: "rec"
  }
  IpcHandler {
    function toggle(): string {
      const active = ipc.toggleLauncher();
      Logger.log("IPC", `launcher.toggle -> ${active ? "open" : "closed"}`);
      return active ? "open" : "closed";
    }

    target: "launcher"
  }
  IpcHandler {
    function clear(): string {
      Logger.log("IPC", "notifications.clear");
      NotificationService.clearAllNotifications();
      return "cleared";
    }

    target: "notifs"
  }
  IpcHandler {
    function mute(): string {
      Logger.log("IPC", "mic.mute");
      return AudioService.toggleMicMute();
    }

    target: "mic"
  }
}
