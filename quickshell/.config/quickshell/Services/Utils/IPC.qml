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

  property bool launcherActive: false

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

  // ----- Application Launcher -----
  IpcHandler {
    function toggle(): string {
      Logger.log("IPC", "launcher.toggle");
      ipc.launcherActive = !ipc.launcherActive;
      return ipc.launcherActive ? "open" : "closed";
    }

    target: "launcher"
  }
}
