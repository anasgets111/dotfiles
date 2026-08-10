# AGENTS.md

This file provides guidance for coding agents working in this repository.

## Project Overview

**Obelisk Shell** — modular Wayland desktop dotfiles centered on **Quickshell** (QML-based shell), supporting **Hyprland** and **Niri** compositors. Managed via GNU Stow.

Primary technologies: QML (Quickshell), Fish shell, Bash scripts.

## Platform Scope

- Arch Linux is authoritative for packages, dependencies, runtime, and installation.
- `NixConfig/` is inactive. Ignore it unless explicitly requested; never use it as context or sync it with Arch.

## Commands

### Shell Scripts

```bash
shellcheck path/to/script.sh    # Lint bash scripts
```

### Quickshell (QML)

- **Never run `stow`**, and never launch the user's live config (`quickshell` bare, `-c`, or `-p` at the real `shell.qml`) — the user handles those
- `quickshell log` (reads the running instance's output) and headless smoke tests are fine
- Headless smoke test: copy the config to a temp dir, add a root QML there that instantiates the component under test inside a `ShellRoot`, and run `quickshell -p /tmp/<copy>/test.qml`. It creates no windows; exit with a `Timer` calling `Qt.quit()`. Bindings still evaluate, so a temporary `console.assert(...)` can verify computed properties. Such a run instantiates the real singletons and touches shared state (`Quickshell.statePath` locks, DBus, PipeWire) — check nothing is in flight first
- Quickshell **hot reloads** on file changes; edits take effect immediately
- For debugging: instrument QML to write output to a file, then read that file — or ask the user to share logs
- Do **not** touch `qmldir`, `.qmlls.ini`, or any Quickshell-managed metadata files
- Shaders are committed as both source and compiled artifact. After editing `Shaders/frag/<name>.frag`, rebuild with the same target set as the existing ones:
  ```bash
  /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
    -o Shaders/qsb/<name>.frag.qsb Shaders/frag/<name>.frag
  ```

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
Command.run(["echo", "hello"], result => {
  // Handle result without logging from QML.
});
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

- Files in the same folder don't need imports, except when referencing a singleton from that folder; import the folder's `qs` namespace so the singleton is resolved
- Use namespace `qs` for project subfolders: `qs.Services.Core` → `Services/Core/`
- Never use `import "."` — always use namespace

**Patterns:**
- Property bindings over assignments (let QML handle reactivity)
- `readonly property` for computed values
- Explicit types: `function setThemeName(name: string): void`
- Use optional chaining (`?.`) and nullish coalescing (`??`)
- Use `try/catch` inside `onLoaded` handlers for JSON parsing
- Use Theme constants — never hardcode colors, sizes, or spacing
- Standard transitions are `Theme.ColorTransition on <prop> {}` and `Theme.NumberTransition on <prop> {}` (inline components in `Config/Theme.qml`). Write a raw `Behavior` only for a genuinely different duration or easing
- `OText` already sets `elide: Text.ElideRight`, `verticalAlignment`, font family/size/weight — do not restate them

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

## Agent Memory & Lessons Learned

Record only non-obvious failures or corrections likely to recur. Keep entries concise and timeless: what fails, why, and what to do instead. Mention versions only when the behavior is genuinely version-bound.

After edits, update or remove nearby stale comments, documentation, examples, and AGENTS.md entries exposed by the work. Prefer deleting obsolete guidance over adding exceptions; do not expand scope into unrelated cleanup.

### Known QML / Quickshell Pitfalls

- A `JsonObject`'s declared properties can still read `undefined` while settings load, even though the object itself is non-null. Keep the `settings?.key ?? default` guards on every read: an unguarded read assigns `undefined` (`Unable to assign [undefined] to "x"`) and, having bound to a property that did not yet exist, never re-evaluates once the real value arrives. The `?? default` fallbacks are load-bearing, not duplicates of the schema defaults.
- `?.` inside a `&&` chain — `a && b?.c && d` — yields `undefined`, not `false`, because `&&` returns the first falsy operand and stops. Coalesce the optional read (`(b?.c ?? false)`) rather than trusting the boolean tail.
- Assigning a new JS array to a `ListView.model` resets the view and destroys every delegate (typed text, focus, per-row scroll). Either give delegates stable identity, or freeze the model while a delegate owns input — see `NetworkPanel.listFrozen`.
- `MprisPlayer.position` only refreshes when you call `positionChanged()`, and each call is a DBus round trip. A player whose bus name has vanished can linger in `Mpris.players`, so every poll then logs `QDBusError("org.freedesktop.DBus.Error.ServiceUnknown")`. Gate position polling on something that proves the read is usable (`positionSupported` and a nonzero length), never on "the panel is open".
- An `IdleMonitor` starts counting when it subscribes, not from the last input. Idle stages rely on that: each stage's gate opens when the previous one completes, then the stage waits its own timeout. Do not flatten the gates into cumulative offsets — see `IdleService.IdleStage`.
- `IdleMonitor.timeout` and `respectInhibitors` are Qt *bindable* properties; a QML binding on them never reaches `IdleMonitor::updateNotification`, so `isIdle` silently stops. Assign both from change handlers (seed with a plain binding that the handler replaces). `enabled` re-registers correctly either way. `Component.onCompleted` is unavailable on `IdleMonitor`.
- Quickshell PipeWire nodes expose `PwNode.properties` and `PwNode.audio` fields only after binding, and they can still be incomplete until `node.ready`; guard bound-property reads and never write volume/mute before readiness.
- Quickshell `BluetoothDevice.pair()` only forwards BlueZ's `Pair()` call; keep a default BlueZ agent registered before offering pairing in the UI.
- Quickshell `Hyprland.dispatch(...)` takes one Lua dispatcher string in this shell. Use forms such as ``Hyprland.dispatch(`hl.dsp.focus({ workspace = 3 })`)``.
- QML method names cannot begin with an uppercase letter; do not expose constructor-style APIs like `function Finder(...)`. Use a lowercase factory such as `createFinder(...)` instead.
- `UPower.displayDevice.state` can flap between `Charging`, `FullyCharged`, and `PendingCharge` while AC remains connected; for battery OSD, do not trigger `Fully Charged` from aggregate terminal-state changes alone. Prefer the edge where charging stops while AC is still connected, and treat `PendingCharge` as its own entry edge.
- Avoid high-frequency add/delete churn on shared JS objects; V4 can crash. Use stable QObject state or scans instead.
- `String.prototype.replaceAll` is not implemented in this QML JS engine; it throws `Property 'replaceAll' of object <str> is not a function` at runtime with no lint-time warning. Use `str.replace(/pattern/g, replacement)` instead.
- A QML import can supply bare types, enums, and singletons even when its module name is never qualified (for example, Quickshell's `Singleton`, `DesktopEntries`, and `ExclusionMode`). Do not remove it based on a text search or an "unused import" lint result; validate a live reload.
- `FolderListModel` can miss `/sys/class/leds` entry replacement on keyboard unplug/replug; on `FileView` failure clear `folder` and restore it on the next poll tick (see `Utils.qml`), and silence that expected transient error.
- Arch's `org.kde.kdeconnect` QML module ships incomplete `.qmltypes`, and `DeviceDbusInterface.type`/`supportedPlugins` are non-bindable despite their change signals. Validate its real types with `qmlplugindump`; copy those two values from `typeChanged`/`pluginsChanged` instead of binding them directly.
- Reuse `Process` objects through `Command`; destroying a process from its own exit handler can use freed memory.
- For commands that need EOF, enable stdin before start and disable it in `onStarted`; failed starts may only report through `onRunningChanged`.
- Verify with `/usr/lib/qt6/bin/qmllint -I <.qmlls.ini buildDir> -I /usr/lib/qt6/qml File.qml`; `qs.*` resolves only via that VFS path, and the `PATH` `qmllint` is Qt5's (silent exit 255). `qmlformat` is a formatter and can fail on valid files.
- `Region.item` tracks only that item's geometry; bind an outer region to the animated ancestor when inherited movement matters. It also ignores `item.visible` — gate exported regions on whether the host draws (see `PanelHost.blurRegion`).
- Hyprland 0.56.1 fades already-mapped `Top` layer surfaces when fullscreen starts, but a lazy `Top` surface mapped after fullscreen is active stays at alpha 1. Guard lazy popups through the WM facade; Niri's native `Top` ordering needs no workaround.
- Declare complex `BackgroundEffect.blurRegion` values as typed properties instead of inline objects that produce unqualified-reference warnings.
- `Animation.finished()` only fires for standalone top-level animations, not animations inside a `Behavior`, `Transition`, or group.
- Follow the active instance's plain `log.log`; `quickshell log -f` can abort independently of a healthy shell.
- In content-sized panels, top-anchor the root layout instead of filling the animated host height; `anchors.fill` compresses every child while the panel resizes.
- High-frequency scene-graph geometry churn can look like a leak because glibc keeps render-thread arenas. Confirm the shape before chasing it — a `var`-property or JS leak grows `memfd:JSGCHeap:QtQml` in `/proc/<pid>/smaps`, while renderer churn grows plain anonymous mappings and leaves the JS heap small.
- Draw many animated primitives as a single `ShaderEffect` quad rather than one item each, and bake state-dependent alpha into the color uniform — `opacity` on the host item pushes the whole subtree into a blended batch. Qt premultiplies `color` uniforms, so `barColor * qt_Opacity` composites the same as an equivalent translucent `Rectangle`. Never feed an animated shader through `Canvas`: Qt 6 ignores `Canvas.FramebufferObject`, and the `Canvas.Image` path deletes and recreates its `QSGTexture` on every paint.
- Qt 6 `ShaderEffect` has no array uniforms; pack fixed-size numeric data into `matrix4x4` uniforms. `Qt.matrix4x4()` also accepts a 16-element array, so one reused scratch array can fill them without allocating per frame. It fills **row-major** while GLSL `mat4` subscripts **column-first**, so element `i` reads back as `m[i % 4][i / 4]`. Bind every matrix to a real value: an unset `matrix4x4` property is *identity*, not zeros, and the diagonal then renders as live data.
- `verticalItemAlignment`/`horizontalItemAlignment` exist on `Grid`, not on `Row` or `Column`. Assigning one to a `Row` makes the whole component fail to instantiate, and the `qml` runtime reports only `Did not load any objects, exiting.` with no property name — `qmllint` names it.
- `Rectangle.antialiasing` defaults to `radius > 0`, which puts the rect on a smooth material (own alpha batch, own `QSGGeometry`). Fine for a few static rects; avoid on anything whose geometry changes every frame.
- A headless `quickshell -p` run creates no window, so layout polish never runs and `Layout.preferredHeight`/`fillHeight` are never applied — children keep their implicit sizes. Headless runs prove instantiation and bindings; check final geometry in the live shell.

## Operational Gotchas

- `niri msg action spawn` gives the child an activation token, which can focus a window despite an `open-focused false` rule. When a script must relocate a new window before focusing it, spawn through `env -u XDG_ACTIVATION_TOKEN` and focus it explicitly afterward.
- `niri` subcommands take their own config option: validate a repository config with `niri validate --config path/to/config.kdl`, not `niri --config path/to/config.kdl validate`.
- `systemd-run --scope` cannot be combined with `--pipe`, and a fixed-name scope may still be loaded briefly after its command exits. For streamed output with an immediately reusable fixed unit name, use a transient service with `--pipe --collect`.
- Secrets in `.local_secrets/` (gitignored) — `.gitconfig` is symlinked from there
- Default terminal is resolved via `xdg-terminal-exec`
