pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Core
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {}
// PowerManagement — responsibilities and layout (comments only; no code yet)
//
// Goals:
// - Provide a cross-WM idle and power management interface (Hyprland/Niri backends).
// - Detect laptop lid presence and lid open/close events.
// - Expose actions: lock, dim, sleep (suspend), hibernate, shutdown.
// - Allow policy configuration (timeouts, inhibit, and per-power-source rules).
//
// Structure:
// - Singleton API surface:
//   - ready (bool): becomes true when backend detection completes.
//   - isLaptop (bool): true if a lid switch is present.
//   - lidClosed (bool): current lid state.
//   - inhibited (bool): global inhibit flag (e.g., for fullscreen video/recording).
//   - timeouts (object): { dimMs, lockMs, sleepMs, hibernateMs, shutdownMs }.
//   - signals:
//       - idleReached(phase): 'dim' | 'lock' | 'sleep' | 'hibernate' | 'shutdown'.
//       - lidChanged(closed: bool).
//       - inhibitedChanged(enabled: bool).
//   - actions (methods): lock(), undim(), dim(), sleep(), hibernate(), shutdown().
//
// Backends:
// - Hyprland: use Hyprland idle/idle_inhibitor or call out to swayidle-compatible behavior.
// - Niri: integrate with niri's idle signals or fallback to a timer-based policy.
// - Fallback: pure QML timers if no native idle is available.
//
// Lid detection:
// - Prefer UPower/Logind or Quickshell.Services.Core hooks if exposed.
// - Fallback: read /proc/acpi/button/lid/*/state or `logind` DBus: org.freedesktop.login1.Manager.HandleLid*.
// - isLaptop := lid device exists. lidClosed binds to event stream.
//
// Policy examples:
// - On AC power: dim at 5 min, lock at 10 min, sleep at 30 min.
// - On battery: dim at 2 min, lock at 5 min, sleep at 10 min, hibernate at 60 min.
// - On lid close: immediate lock; sleep/hibernate depending on power state and user pref.
//
// Actions wiring:
// - lock(): toggle Core.LockService.locked = true.
// - dim(): emit idleReached('dim') for UI to fade brightness overlay; reversible via undim().
// - sleep(): call `systemctl suspend` via Quickshell.Io.Process.
// - hibernate(): call `systemctl hibernate`.
// - shutdown(): call `systemctl poweroff`.
// - Respect inhibited: do not advance past 'dim' while inhibited; reset timers on user input.
//
// Integration points:
// - Quickshell input activity hooks (keyboard/mouse) to reset idle timers.
// - UPower power source to select timeouts (AC vs battery).
// - Recording/Media services to set inhibited=true while active if desired.
// - Expose DBus-like inhibit cookie API (optional) for apps to inhibit temporally.
//
// Future considerations:
// - Per-output dimming and turning displays off via DPMS.
// - Configurable actions on lid close per power source.
// - Handle Wayland session lock protocol ordering (lock before suspend).
// - Emit detailed telemetry for UI indicators.
