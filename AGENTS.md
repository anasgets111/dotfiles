# AGENTS.md - Obelisk Shell Dotfiles

## Project Overview

Wayland desktop dotfiles centered on **Quickshell** (QML-based shell), supporting **Hyprland** and **Niri** compositors. Managed via **GNU Stow**.

**Primary technologies**: QML (Quickshell), Fish shell

## Build / Test / Lint Commands

### Quickshell (QML)

- **Run**: `quickshell` (interprets QML, no compilation)
- **No formatter needed**
- **Check**: Run `quickshell log`, check output for errors
- **No unit tests** - Quickshell is interpreted

### Deployment (Stow)

```bash
# Deploy core packages
stow -t ~ quickshell hypr niri fish kitty nvim home config

# Deploy optional
stow -t ~ swaylock swaync swayosd waybar swayidle ghostty alacritty nushell

# Remove
stow -D -t ~ <package>
```

## Code Style Guidelines

### QML (Quickshell)

**Pragmas:**

- Services: `pragma Singleton`
- Components: `pragma ComponentBehavior: Bound`

**Naming:**

- Services: PascalCase (`AudioService.qml`)
- Components: PascalCase (`IconButton.qml`)
- Properties: camelCase
- Private/internal: `_prefix`

**Imports:**

- Never `import "."` - use namespace: `import qs.Services.Core`
- Standard order: Qt → Quickshell → qs namespaces

**Patterns:**

- Prefer arrow functions/ternary over imperative
- Use `readonly property` for computed values
- Use optional chaining (`?.`) and nullish coalescing (`??`)
- Property bindings over assignments

**Error Handling:**

- Don't validate internal code
- Only validate at boundaries (user input, external APIs)

**Example:**

```qml
pragma Singleton
import QtQuick
import Quickshell
import qs.Services.Utils

Singleton {
  id: root
  readonly property bool isReady: internalReady ?? false
  readonly property string displayName: node?.description ?? "Unknown"
  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }
}
```

## Architecture

### Quickshell Structure

```text
quickshell/.config/quickshell/
  shell.qml          # Entry point
  Components/        # Reusable UI components
  Modules/           # Bar, AppLauncher, Notification, OSD
  Services/          # Singleton business logic
    Core/           # Audio, Battery, Brightness
    SystemInfo/     # System state
    Utils/          # IPC, Logger
    WM/             # Workspace/compositor abstraction
  Config/           # Theme.qml, Settings.qml
  Assets/           # Icons, shaders
```

### Service Pattern

- All services are QML singletons
- Use `Logger.log("ServiceName", "message")` for debugging
- Access via singleton pattern

### Compositor Detection

Check before WM-specific features:

```qml
if (MainService.currentWM === "hyprland") {
  // Hyprland IPC
} else if (MainService.currentWM === "niri") {
  // Niri commands
}
```

## Key Principles

- **Check context7 or online** documentation about relevant topics for example quickshell-git
- **Always check existing code** before adding new functionality
- **Prefer concise code** - Use least amount of code possible
- **Avoid over-engineering** - Only make directly requested changes
- **DRY principle** - Reuse existing abstractions
- **No unnecessary abstractions** - Don't create helpers for one-time operations
