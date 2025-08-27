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
        target: "lock"

        function lock(): string {
            Logger.log("IPC", "lock");
            LockService.locked = true;
            return "locked";
        }
        function unlock(): string {
            Logger.log("IPC", "unlock");
            LockService.locked = false;
            return "unlocked";
        }
        function toggle(): string {
            Logger.log("IPC", "toggle");
            LockService.locked = !LockService.locked;
            return LockService.locked ? "locked" : "unlocked";
        }
        function status(): string {
            const s = LockService.locked ? "locked" : "unlocked";
            Logger.log("IPC", `status -> ${s}`);
            return s;
        }
        function islocked(): string {
            return LockService.locked ? "true" : "false";
        }
    }

    // ----- Audio -----
    IpcHandler {
        target: "audio"

        function setvolume(percentage: string): string {
            Logger.log("IPC", "setvolume", percentage);
            return AudioService.setVolume(percentage);
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
        function mute(): string {
            Logger.log("IPC", "mute");
            return AudioService.toggleMute();
        }
        function setmic(percentage: string): string {
            Logger.log("IPC", "setmic", percentage);
            return AudioService.setMicVolume(percentage);
        }
        function micmute(): string {
            Logger.log("IPC", "micmute");
            return AudioService.toggleMicMute();
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
    }

    // ----- OSD -----
    IpcHandler {
        target: "osd"

        function info(message: string): string {
            OSDService.showInfo(message, "");
            return "ok";
        }
        function warn(message: string): string {
            OSDService.showWarning(message, "");
            return "ok";
        }
        function error(message: string): string {
            OSDService.showError(message, "");
            return "ok";
        }
        function showlvl(message: string, level: int): string {
            OSDService.showToast(message, level, "");
            return "ok";
        }
        function infod(message: string, details: string): string {
            OSDService.showInfo(message, details);
            return "ok";
        }
        function warnd(message: string, details: string): string {
            OSDService.showWarning(message, details);
            return "ok";
        }
        function errord(message: string, details: string): string {
            OSDService.showError(message, details);
            return "ok";
        }
        function showlvld(message: string, level: int, details: string): string {
            OSDService.showToast(message, level, details);
            return "ok";
        }
        function hide(): string {
            OSDService.hideToast();
            return "hidden";
        }
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
        function status(): string {
            return `OSD: visible=${OSDService.toastVisible}, queued=${OSDService.toastQueue.length}, level=${OSDService.currentLevel}, repeats=${OSDService.currentRepeatCount}, DND=${OSDService.doNotDisturb}`;
        }
    }

    // ----- Notifications -----
    IpcHandler {
        target: "notifs"

        function clear(): string {
            NotificationService.clearAll();
            return "cleared";
        }
        function send(summary: string, body: string, optionsJson: string): string {
            let opts = {};
            try {
                if (optionsJson)
                    opts = JSON.parse(String(optionsJson));
            } catch (e) {
                opts = {};
            }
            const id = NotificationService.send(summary ?? "", body ?? "", opts ?? {});
            return id || "";
        }

        function clearhistory(): string {
            NotificationService.clearHistory();
            return "History cleared";
        }
        function status(): string {
            const dnd = NotificationService.dndPolicy ? (NotificationService.dndPolicy.enabled ? "on" : "off") : "off";
            const behavior = NotificationService.dndPolicy && NotificationService.dndPolicy.behavior ? NotificationService.dndPolicy.behavior : "queue";
            const groupsCount = (NotificationService.groups && typeof NotificationService.groups === "function") ? NotificationService.groups().length : 0;
            const historyCount = NotificationService.historyModel ? NotificationService.historyModel.count : 0;
            return `Notifications: total=${NotificationService.all.length}, visible=${NotificationService.visible.length}, queued=${NotificationService.queue.length}, history=${historyCount}, groups=${groupsCount}, dnd=${dnd}(${behavior}), maxVisible=${NotificationService.maxVisible}, expire=${NotificationService.expirePopups}`;
        }
    }

    // ----- Media (MPRIS) -----
    IpcHandler {
        target: "mpris"

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
        function play(): void {
            if (MediaService.active && MediaService.active.canPlay)
                MediaService.active.play();
        }
        function pause(): void {
            if (MediaService.active && MediaService.active.canPause)
                MediaService.active.pause();
        }
        function playPause(): void {
            if (MediaService.active && MediaService.active.canTogglePlaying)
                MediaService.active.togglePlaying();
        }
        function previous(): void {
            if (MediaService.active && MediaService.active.canGoPrevious)
                MediaService.active.previous();
        }
        function next(): void {
            if (MediaService.active && MediaService.active.canGoNext)
                MediaService.active.next();
        }
        function stop(): void {
            if (MediaService.active)
                MediaService.active.stop();
        }
        function seek(position: real): void {
            MediaService.seek(position);
        }
        function seekByRatio(ratio: real): void {
            MediaService.seekByRatio(ratio);
        }
    }
}
