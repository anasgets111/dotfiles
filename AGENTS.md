# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

Always check before using WM-specific features:

```qml
if (MainService.currentWM === "hyprland") { ... }
else if (MainService.currentWM === "niri") { ... }
// Values: "hyprland", "niri", "other"
```

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
- No qmldir files needed — Quickshell handles discovery automatically

**Patterns:**
- Property bindings over assignments (let QML handle reactivity)
- `readonly property` for computed values
- Explicit types: `function setThemeName(name: string): void`
- Use `Logger.log("ServiceName", "message", "warning")` for debugging
- Use optional chaining (`?.`) and nullish coalescing (`??`)
- Use `try/catch` inside `onLoaded` handlers for JSON parsing
- Use Theme constants — never hardcode colors, sizes, or spacing

## Key Principles

1. **Check documentation first** — Use Context7 MCP for Quickshell/QML topics
2. **Check existing code** — Look at similar files before adding functionality
3. **DRY** — Reuse existing abstractions (Theme, Logger, IPC, etc.)
4. **Property bindings over assignments**
5. **Compositor detection** — Never use WM-specific features without checking `MainService.currentWM`

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

---

## Operational Gotchas

- `monitors.conf` is gitignored (host-specific) — create it manually per machine
- Secrets in `.local_secrets/` (gitignored) — `.gitconfig` is symlinked from there
- Waybar, swaync, swayosd, swaylock are all deprecated; Quickshell handles all UI
- Default terminal is resolved via `xdg-terminal-exec`
