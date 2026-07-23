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
  shell.qml       # Entry point
  Components/     # Reusable UI
  Modules/        # Bar, global UI, notifications, OSD, shell hosts
  Services/       # Core, system info, UI state, utilities, WM facades/adapters
  Config/         # Theme and persistent settings
  Assets/         # Color schemes and generated assets
  Shaders/        # Fragment sources and compiled QSB shaders
```

### Service Pattern

Global state services use `pragma Singleton` and are accessed directly, for example `Settings.data.themeName`. Helper types under `Services/` need not be singletons. Prefer reactive bindings; use `Component.onCompleted` only for imperative startup work.

### Compositor Detection

`MainService.currentWM` (`"hyprland"`, `"niri"`, `"other"`) is the **seam**, not a tool for callers. Do **not** branch on it in services, panels, or UI.

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
Command.run(["echo", "hello"], result => Logger.log("Example", result.stdout));
Command.detached(["xdg-open", url]);
```

### Environment Variables

```qml
Quickshell.env("XDG_CURRENT_DESKTOP")
Quickshell.env("HOME")
```

## QML Code Style

**Pragmas:** Global services → `pragma Singleton`; reusable components → `pragma ComponentBehavior: Bound` when required

**Naming:** Services/components PascalCase, properties camelCase, private `_prefix`; signals describe events (`clicked`, `loaded`, `closeRequested`) and handlers use `onClicked`, `onLoaded`, etc.

**Imports order:**
```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services.Utils
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
- `home/.profile` — XDG dirs, NVIDIA env vars, Wayland toolkit config, PATH
- `fish/.config/fish/conf.d/various.fish` — Custom fish functions
- `quickshell/.config/quickshell/.qmlformat.ini` — QML formatting rules
- `NixConfig/` — NixOS flake for hosts Wolverine (NVIDIA/Hyprland) and Mentalist (Intel/Niri)

## Agent Memory & Lessons Learned

Record only non-obvious failures or corrections likely to recur. Keep entries concise and timeless: what fails, why, and what to do instead. Mention versions only when the behavior is genuinely version-bound.

After edits, update or remove nearby stale comments, documentation, examples, and AGENTS.md entries exposed by the work. Prefer deleting obsolete guidance over adding exceptions; do not expand scope into unrelated cleanup.

### Known QML / Quickshell Pitfalls

<!-- Add entries below as they are discovered -->
- Quickshell PipeWire nodes expose `PwNode.properties` and `PwNode.audio` fields only after binding, and they can still be incomplete until `node.ready`; guard bound-property reads and never write volume/mute before readiness.
- Quickshell `Hyprland.dispatch(...)` takes one Lua dispatcher string in this shell. Use forms such as ``Hyprland.dispatch(`hl.dsp.focus({ workspace = 3 })`)``.
- QML method names cannot begin with an uppercase letter; do not expose constructor-style APIs like `function Finder(...)`. Use a lowercase factory such as `createFinder(...)` instead.
- `UPower.displayDevice.state` can flap between `Charging`, `FullyCharged`, and `PendingCharge` while AC remains connected; for battery OSD, do not trigger `Fully Charged` from aggregate terminal-state changes alone. Prefer the edge where charging stops while AC is still connected, and treat `PendingCharge` as its own entry edge.
- Avoid high-frequency add/delete churn on shared JS objects; V4 can crash. Use stable QObject state or scans instead.
- Reuse `Process` objects through `Command`; destroying a process from its own exit handler can use freed memory.
- For commands that need EOF, enable stdin before start and disable it in `onStarted`; failed starts may only report through `onRunningChanged`.
- Use `qmllint` for syntax verification. `qmlformat` is a formatter and can fail on valid files.
- `Region.item` tracks only that item's geometry; bind an outer region to the animated ancestor when inherited movement matters.
- Declare complex `BackgroundEffect.blurRegion` values as typed properties instead of inline objects that produce unqualified-reference warnings.
- `Animation.finished()` only fires for standalone top-level animations, not animations inside a `Behavior`, `Transition`, or group.
- Follow the active instance's plain `log.log`; `quickshell log -f` can abort independently of a healthy shell.

## Operational Gotchas

- `niri msg action spawn` gives the child an activation token, which can focus a window despite an `open-focused false` rule. When a script must relocate a new window before focusing it, spawn through `env -u XDG_ACTIVATION_TOKEN` and focus it explicitly afterward.
- `niri` subcommands take their own config option: validate a repository config with `niri validate --config path/to/config.kdl`, not `niri --config path/to/config.kdl validate`.
- `systemd-run --scope` cannot be combined with `--pipe`, and a fixed-name scope may still be loaded briefly after its command exits. For streamed output with an immediately reusable fixed unit name, use a transient service with `--pipe --collect`.
- Secrets in `.local_secrets/` (gitignored) — `.gitconfig` is symlinked from there
- Waybar, swaync, swayosd, swaylock are all deprecated; Quickshell handles all UI
- Default terminal is resolved via `xdg-terminal-exec`
