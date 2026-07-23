# AGENTS.md

This file provides guidance for coding agents working in this repository.

## Project Overview

**Obelisk Shell** — modular Wayland desktop dotfiles centered on **Quickshell** (QML-based shell), supporting **Hyprland** and **Niri** compositors. Managed via GNU Stow.

Primary technologies: QML (Quickshell), Fish shell, Bash scripts.

## Commands

### Shell Scripts

```bash
shellcheck path/to/script.sh    # Lint bash scripts
```

### Quickshell (QML)

- **Never run `quickshell` or `stow`** — the user handles these
- Quickshell **hot reloads** on file changes; edits take effect immediately
- For debugging: instrument QML to write output to a file, then read that file — or ask the user to share logs
- Do **not** touch `qmldir`, `.qmlls.ini`, or any Quickshell-managed metadata files

## Architecture

### Quickshell Structure

```
quickshell/.config/quickshell/
  shell.qml              # Entry point — loads all modules
  Components/            # Reusable UI (OButton, OInput, Slider, IconButton…)
  Modules/               # Bar, AppLauncher, Notification, OSD, Global
  Services/              # Singleton business logic
    Core/               # Audio, Battery, Brightness, Wallpaper, Lock…
    SystemInfo/         # Time, Weather, Notifications, Updates
    Utils/              # IPC, Logger, Fzf, Utils
    WM/                 # Workspace abstraction with Hyprland/Niri implementations
  Config/               # Theme.qml, Settings.qml
  Assets/               # Icons, ColorScheme, shaders
  Greeter/              # Login screen component
```

### Service Pattern

All services use `pragma Singleton` and are accessed directly: `Settings.data.themeName`. Initialize in `Component.onCompleted`.

### Compositor Detection

`MainService.currentWM` (`"hyprland"`, `"niri"`, `"other"`) is the **seam**, not a tool for callers. Do **not** branch on it in services, panels, or UI — that reintroduces the leaks the WM seam was built to remove. See `CONTEXT.md` for the vocabulary (compositor, adapter, WM facade).

The brand may only be compared in one place: a WM facade's `backend` selector.

```qml
// In Services/WM/<X>Service.qml — the ONLY allowed currentWM comparison:
readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.XImpl
  : MainService.currentWM === "niri" ? Niri.XImpl : null
```

Everywhere else, ask the facade *what the compositor can do*, never *which one it is*:

```qml
// Imperative compositor action → CompositorService (DPMS, session exit)
CompositorService.setDisplaysPowered(false);
CompositorService.exitSession();

// Capability gate → a facade capability property, backed per-adapter
Loader { active: WorkspaceService.supportsSpecialWorkspaces; /* ... */ }
```

Missing an operation or capability? Add it to the adapter interface
(`Services/WM/Impl/{Hyprland,Niri}/*Impl.qml`) and surface it on the facade — don't
add a `currentWM` branch at the call site.

### Settings Persistence

```qml
JsonAdapter {
  property string themeMode: "dark"
  property JsonObject idleService: JsonObject {
    property bool enabled: true
  }
}
```

### Running Commands Asynchronously

```qml
Process {
  command: ["sh", "-c", "echo hello"]
  onFinished: => console.log(stdout)
}
// For IPC: IPC.spawn(command)
```

### Environment Variables

```qml
Quickshell.env("XDG_CURRENT_DESKTOP")
Quickshell.env("HOME")
```

## QML Code Style

**Pragmas:** Services → `pragma Singleton`, Components → `pragma ComponentBehavior: Bound`

**Naming:** Services/Components PascalCase, properties camelCase, private `_prefix`, signals past tense (`onLoaded`, `onClicked`)

**Imports order:**
```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Config
```

- Files in the same folder don't need imports
- Use namespace `qs` for project subfolders: `qs.Services.Core` → `Services/Core/`
- Never use `import "."` — always use namespace

**Patterns:**
- Property bindings over assignments (let QML handle reactivity)
- `readonly property` for computed values
- Explicit types: `function setThemeName(name: string): void`
- Use `Logger.log("ServiceName", "message")`, `Logger.warn(...)`, or `Logger.error(...)` as appropriate
- Use optional chaining (`?.`) and nullish coalescing (`??`)
- Use `try/catch` inside `onLoaded` handlers for JSON parsing
- Use Theme constants — never hardcode colors, sizes, or spacing

## Ponytail: Lazy Senior Dev Mode

Lazy means efficient, not careless. The best code is the code never written.

Before writing code, understand the task and trace the real flow end to end. For Quickshell/QML topics, check the relevant documentation first (use Context7 MCP). Then stop at the first rung that holds:

1. Does this need to be built at all? (YAGNI)
2. Does it already exist in this codebase? Reuse the helper, utility, or pattern; do not rewrite it.
3. Does the standard library already do this? Use it.
4. Does a native platform feature cover it? Use it.
5. Does an installed dependency solve it? Use it.
6. Can this be one line? Make it one line.
7. Only then, write the minimum code that works.

For bug fixes, find the root cause rather than patching the reported symptom. Grep every caller of a touched function and fix the shared function once when that protects all callers; do not leave sibling paths broken.

- No abstractions, dependencies, boilerplate, or files unless explicitly needed.
- Prefer deletion over addition, boring over clever, and the fewest files possible.
- The shortest working diff wins only after understanding the problem; the smallest change in the wrong place is a second bug.
- Question complex requests: does the requested feature need to exist, or does an existing option cover it?
- When similarly sized standard approaches exist, choose the edge-case-correct one.
- Mark a deliberate simplification with a real ceiling (for example, a global lock, O(n²) scan, or naive heuristic) using a `ponytail:` comment that names the ceiling and upgrade path.

Do not be lazy about understanding the problem, trust-boundary validation, data-loss prevention, security, accessibility, real-hardware calibration, or anything explicitly requested. Non-trivial logic needs one runnable, minimal check (an assert-based self-check or small test file); trivial one-liners do not.

## Notable Files

- `bin/.local/bin/update` — System-wide update orchestrator (pacman, bun, cargo, fnm)
- `bin/.local/bin/setup-greetd` — Login screen installer
- `home/.profile` — XDG dirs, NVIDIA env vars, Wayland toolkit config, PATH
- `fish/.config/fish/conf.d/various.fish` — Custom fish functions
- `.qmlformat.ini` — QML formatting rules
- `NixConfig/` — NixOS flake for hosts Wolverine (NVIDIA/Hyprland) and Mentalist (Intel/Niri)

## Agent Memory & Lessons Learned

This section is a living record of findings from repeated interactions. When Claude (or any agent) discovers something that fails, is corrected by the user, or comes up repeatedly — it **must be documented here** so future sessions don't repeat the same mistakes.

### How to update this section
- If the user corrects you on something for the second time, add it here immediately
- If you try something and it fails (runtime error, incompatible syntax, etc.), add it here
- Keep entries concise: what was tried, why it fails, what to do instead

### Known QML / Quickshell Pitfalls

<!-- Add entries below as they are discovered -->
- Quickshell PipeWire nodes expose `PwNode.properties` and `PwNode.audio` fields only after binding, and they can still be incomplete until `node.ready`; guard bound-property reads and never write volume/mute before readiness.
- Destroying a `ScreencopyView` immediately after async `Loader` creation (for example with `Loader.onLoaded: active = false`) can trigger `wl_proxy_get_listener called with a null proxy`; keep the loader active and let the view live normally.
- Niri does not provide a Hyprland-style session-lock xray path for transparent lock surfaces; if a Quickshell lock surface relies on transparency or screencopy under lock, Niri will show its red locked-session background instead, so gate that effect by compositor and fall back to an opaque background.
- Quickshell `Hyprland.dispatch(...)` is a one-argument API on Hyprland 0.55+; old forms like `Hyprland.dispatch("workspace 3")` or `Hyprland.dispatch("workspace", "3")` break because Hyprland now parses dispatch requests as Lua. Use a Lua dispatcher string such as ``Hyprland.dispatch(`hl.dsp.focus({ workspace = 3 })`)`` instead.
- QML method names cannot begin with an uppercase letter; do not expose constructor-style APIs like `function Finder(...)`. Use a lowercase factory such as `createFinder(...)` instead.
- `UPower.displayDevice.state` can flap between `Charging`, `FullyCharged`, and `PendingCharge` while AC remains connected; for battery OSD, do not trigger `Fully Charged` from aggregate terminal-state changes alone. Prefer the edge where charging stops while AC is still connected, and treat `PendingCharge` as its own entry edge.
- High-frequency **add + `delete` of named keys on a `property var` JS object** (e.g. an `{}` used as a set, mutated `obj[key]=true` / `delete obj[key]` on every tick) segfaults V4 in `QV4::Object::insertMember` — the churn forces repeated internal-class transitions. The crash surfaces as a `StoreElement` inside whatever timer fired the write, not where the object lives. Track such transient state another way (e.g. flags on long-lived QObjects, scanned), not by churning keys on a shared var object. Occasional mutation (stable keys, low frequency) is fine. This is why `Services/Utils/Command.qml` tracks in-flight "lanes" by scanning its `Process` pool instead of a `{}` set.
- Reuse long-lived `Process` objects rather than `Component.createObject` + `destroy()` per command: destroying a Quickshell `Process` from inside its own `onExited` is a use-after-free. `StdioCollector` resets its buffer between runs, so reuse is safe.
- Quickshell `Process.stdinEnabled: false` closes the QProcess write channel before startup, which can leave children such as `slurp` blocked reading an open pipe. Enable stdin before each run and disable it in `onStarted`; also clean up from `onRunningChanged` because failed starts do not emit `exited`.
- Quickshell `ObjectModel.get(i)` takes a numeric **index**, not a key. To look up by identity (e.g. a Bluetooth device by MAC), search `model.values.find(x => x.key === …)` — `model.get(address)` silently returns null, which makes every action routed through it (connect/forget/…) a no-op.
- Qt 6.11.1 `qmlformat` is not a reliable verifier for every service file here: it exits 1 on `NotificationService.qml`/`OSDService.qml` and segfaults on `PrivacyService.qml`/`NotificationText.qml` even when `qmllint` accepts them. Use `qmllint` for syntax verification on those files.
- Quickshell `Region.item` listens to that item's own geometry changes, not movement inherited from an animated ancestor. When a child item defines an inset region inside a sliding card, wrap it in an outer `Region { item: slidingCard }` so the region rebuilds on every animation frame; pointing directly at the inset child leaves the blur behind.
- An inline `BackgroundEffect.blurRegion: Region { ... }` inside a `PopupWindow` makes references such as `subPopup.width` lint as unqualified. Declare a typed `readonly property Region blurRegion` on the window and assign `BackgroundEffect.blurRegion: subPopup.blurRegion` instead.
- Qt only emits `Animation.finished()` for top-level standalone animations, never for animations inside a `Behavior`, `Transition`, or animation group. When modal dismissal owns a layer-shell input mask or exclusive keyboard focus, drive the transition with a standalone animation and release ownership from its `onFinished`; a handler inside `Behavior` will never run.
- `quickshell log -f` can abort while the shell remains healthy because its `LogFollower` may destroy a thread still blocked on the encoded log lock. For terminal log helpers, follow the live instance's plain `log.log` directly instead of launching the encoded-log follower.

---

## Operational Gotchas

- `niri msg action spawn` gives the child an activation token, which can focus a window despite an `open-focused false` rule. When a script must relocate a new window before focusing it, spawn through `env -u XDG_ACTIVATION_TOKEN` and focus it explicitly afterward.
- `niri` subcommands take their own config option: validate a repository config with `niri validate --config path/to/config.kdl`, not `niri --config path/to/config.kdl validate`.
- `systemd-run --scope` cannot be combined with `--pipe`, and a fixed-name scope may still be loaded briefly after its command exits. For streamed output with an immediately reusable fixed unit name, use a transient service with `--pipe --collect`.
- `monitors.conf` is gitignored (host-specific) — create it manually per machine
- Secrets in `.local_secrets/` (gitignored) — `.gitconfig` is symlinked from there
- Waybar, swaync, swayosd, swaylock are all deprecated; Quickshell handles all UI
- Default terminal is resolved via `xdg-terminal-exec`
