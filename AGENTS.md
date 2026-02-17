# AGENTS.md - Obelisk Shell Dotfiles

## Project Overview

Wayland desktop dotfiles centered on **Quickshell** (QML-based shell), supporting **Hyprland** and **Niri** compositors.

**Primary technologies**: QML (Quickshell), Fish shell

## Build / Test / Lint Commands

### Quickshell (QML)

```bash
# Run Quickshell (interprets QML, no compilation)
quickshell

# Check for errors - inspect quickshell log output
quickshell log

# Run with verbose logging
quickshell --v
```

**No unit tests** - Quickshell is interpreted

**No formatter needed** - QML formatting is handled by the Qt extension

### Shell Scripts

```bash
# Lint shell scripts with shellcheck
shellcheck path/to/script.sh
```

## Code Style Guidelines

### QML (Quickshell)

**Pragmas:**
- Services: `pragma Singleton`
- Components: `pragma ComponentBehavior: Bound`

**Naming Conventions:**
- Services: PascalCase (`AudioService.qml`, `MainService.qml`)
- Components: PascalCase (`IconButton.qml`, `OButton.qml`)
- Properties: camelCase
- Private/internal: `_prefix` (e.g., `_loadedScheme`)
- Signals: past tense (e.g., `onLoaded`, `onClicked`, `onFileChanged`)

**Imports - Standard Order:**
```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Services.Utils
import qs.Config
```

- Files in the same folder don't need imports
- Use namespace `qs` to import from project subfolders: `qs.Services.Core` imports from `Services/Core/`
- Never use `import "."` - always use namespace
- No need to worry about qmldir files - Quickshell handles this automatically

**Types:**
- Use explicit types: `function setThemeName(name: string): void`
- Use `readonly property` for computed values
- Common types: `string`, `bool`, `int`, `real`, `var` (dynamic)

**Code Patterns:**
- Use property bindings over assignments
- Use `JsonObject` and `JsonAdapter` for settings persistence
- Use `FileView` for file watching/loading
- Use optional chaining (`?.`) and nullish coalescing (`??`)
- Use `Logger.log("ServiceName", "message", "warning")` for debugging

**Error Handling:**
- Use try/catch in `onLoaded` handlers for JSON parsing
- Only validate at boundaries (user input, external APIs)

## Architecture

### Quickshell Structure

```
quickshell/.config/quickshell/
  shell.qml              # Entry point
  Components/            # Reusable UI (OButton, OInput, Slider)
  Modules/               # Bar, AppLauncher, Notification, OSD, Global
  Services/              # Singleton business logic
    Core/               # Audio, Battery, Brightness, Wallpaper
    SystemInfo/         # Time, Weather, Notifications
    Utils/              # IPC, Logger, Fzf, Utils
    WM/                 # Workspace abstraction (Hyprland/Niri impl)
  Config/               # Theme.qml, Settings.qml
  Assets/               # Icons, ColorScheme, shaders
```

### Service Pattern

- All services are QML singletons with `pragma Singleton`
- Access via singleton: `Settings.data.themeName`
- Use `Component.onCompleted` for initialization
- Use `Process` for async command execution

### Compositor Detection

Always check before WM-specific features:

```qml
if (MainService.currentWM === "hyprland") {
  // Hyprland IPC
} else if (MainService.currentWM === "niri") {
  // Niri commands
}
```

Values: `"hyprland"`, `"niri"`, `"other"`

### Settings Persistence

Use `JsonAdapter` with `FileView`:

```qml
JsonAdapter {
  property string themeMode: "dark"
  property JsonObject idleService: JsonObject {
    property bool enabled: true
    property int lockTimeoutSec: 300
  }
}
```

### Environment Variables

```qml
Quickshell.env("XDG_CURRENT_DESKTOP")
Quickshell.env("HOME")
Quickshell.env("XDG_CACHE_HOME")
```

### Running Commands

Use `Process` for async commands:

```qml
Process {
  command: ["sh", "-c", "echo hello"]
  onFinished: => console.log(stdout)
}
```

For async IPC use `IPC` service: `IPC.spawn(command)`

## Key Principles

1. **Check documentation** - Use Context7 for Quickshell/QML topics
2. **Check existing code** - Look at similar files before adding functionality
3. **Prefer concise code** - Use least amount of code possible
4. **Avoid over-engineering** - Only make directly requested changes
5. **DRY principle** - Reuse existing abstractions (Theme, Logger, etc.)
6. **Property bindings over assignments** - Let QML handle reactivity
7. **Use Theme constants** - Never hardcode colors, sizes, or spacing

## Keeping This File Updated

If you discover critical information that would take 5+ prompts for another agent to figure out (e.g., non-obvious import behavior, undocumented quirks, essential patterns), add it to this file. Focus on things that are impossible or very hard to learn without explicit guidance.
