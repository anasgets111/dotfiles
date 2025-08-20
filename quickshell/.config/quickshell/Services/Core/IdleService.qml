pragma Singleton
import Quickshell

Singleton {
    id: root
}
// PowerManagement — Tasks Checklist
//
// Core
// [ ] ready flag: expose readonly `ready` (mirrors MainService.ready)
// [ ] lid switch presence: expose readonly `hasLidSwitch` (via MainService.isLaptop)
// [ ] lid open/close state: expose readonly `lidClosed` and update from backend (logind/UPower or /proc)
// [ ] inhibited flag: `property bool inhibited`; emit `inhibitedChanged`
// [ ] idle thresholds: `idleBeforeLockMs`, `idleBeforeDisplayOffMs`, `idleBeforeSleepMs`
//
// Signals & Actions
// [ ] signals: `idleReached(phase)`, `lidChanged(closed: bool)`, `inhibitedChanged(enabled: bool)`
// [ ] actions: `lock()`, `undim()`, `dim()`, `sleep()`, `hibernate()`, `shutdown()`
//
// Backends
// [ ] Hyprland idle backend: integrate idle/idle_inhibitor or swayidle-compatible behavior
// [ ] Niri idle backend: integrate niri idle signals or timer-based fallback
// [ ] Fallback timers: QML timer chain dim -> lock -> display off -> sleep
//
// Policy
// [ ] UPower power source policy: bind AC/Battery
// [ ] Per-power-source timeouts: AC (5/10/30), Battery (2/5/10/60)
// [ ] Respect inhibited: do not advance past 'dim' while `inhibited`; reset on input
//
// Integration
// [ ] Input activity hooks: reset idle timers on keyboard/mouse
// [ ] Recording/media inhibit: set `inhibited = true` while active (optional)
// [ ] Inhibit cookie API: optional; ref-counted inhibit cookies
//
// Future
// [ ] Per-output dim/DPMS control
// [ ] Lid-close actions policy per power source
// [ ] Lock-before-suspend ordering
// [ ] Telemetry & UI indicators
