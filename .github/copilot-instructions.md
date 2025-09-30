# Obelisk Shell - AI Coding Agent Instructions

## Project Overview

**Obelisk Shell** is a modular Wayland desktop environment built on **Quickshell** (QML-based shell framework), supporting both **Hyprland** and **Niri** compositors. All configurations are managed via **GNU Stow** for symlink-based deployment.

## Architecture & Core Patterns

### Stow Package Structure

Each top-level directory is a **Stow package** that symlinks into `$HOME`:

- **Core packages**: `quickshell`, `hypr`, `niri`, `fish`, `kitty`, `nvim`, `home`, `config`
- **Optional packages**: `swaylock`, `swaync`, `swayosd`, `waybar` (deprecated, kept for fallback)

Deploy with: `stow -t ~ <package>...` | Remove with: `stow -D -t ~ <package>`

### Quickshell QML Architecture

**Location**: `quickshell/.config/quickshell/`

#### Directory Structure

```
shell.qml           # Root entry point with ShellRoot
Components/         # Reusable UI components (IconButton, Tooltip, ContextMenu, LockScreen)
Modules/            # Feature modules (Bar, AppLauncher, WallpaperPicker, Notification, OSD)
Services/           # Singleton business logic
  Core/            # Hardware/system services (Audio, Battery, Bluetooth, Network, Wallpaper, etc.)
  SystemInfo/      # System state (Time, Weather, Notifications, Updates, ScreenRecording)
  Utils/           # Cross-cutting (IPC, Logger)
  WM/              # Workspace/compositor abstraction (Hyprland/Niri)
  MainService.qml  # System detection singleton
Config/            # Theme.qml (responsive scaling), Settings.qml
Assets/            # Icons, images
Shaders/           # GLSL shaders for effects
```

#### Key Patterns

**1. Singleton Services**
All services are QML singletons (e.g., `MainService`, `AudioService`, `IPC`). Import with:

```qml
import qs.Services.Core        // Core services (Audio, Network, etc.)
import qs.Services.SystemInfo  // SystemInfo services (Time, Weather, etc.)
import qs.Services.Utils       // IPC, Logger
import qs.Services.WM          // Workspace management
```

**2. Component Behavior Pragma**
Always use at the top of component files:

```qml
pragma ComponentBehavior: Bound
```

**3. Lazy Loading Pattern**
Use `LazyLoader` for expensive components (from Quickshell framework):

```qml
LazyLoader {
    active: condition
    component: SomeComponent { ... }
}
```

**4. Multi-Monitor Handling**
Use `Variants` to instantiate per-monitor components:

```qml
Variants {
    model: MonitorService.monitors
    LazyLoader {
        property var modelData  // Current monitor
        component: PerMonitorComponent { modelData: walLoader.modelData }
    }
}
```

**5. Logging Convention**
Use `Logger.log("ModuleName", "message")` for debugging:

```qml
import qs.Services.Utils  // Provides Logger singleton
Logger.log("NetworkService", `Connected to ${ssid}`)
```

**6. IPC System**
Centralized in `Services/Utils/IPC.qml`. Command structure:

```bash
quickshell ipc call <target> <function> [args...]
# Examples:
quickshell ipc call lock lock          # Lock screen
quickshell ipc call media toggle       # Play/pause media
```

Each `IpcHandler` block defines a target:

```qml
IpcHandler {
    target: "lock"
    function lock(): string { ... }
    function unlock(): string { ... }
}
```

**7. Responsive Theming**
`Config/Theme.qml` calculates `baseScale` from monitor diagonal + DPR. Access via:

```qml
import qs.Config  // Provides Theme singleton
width: Theme.baseScale * 200
```

**8. System Detection**
`MainService` (singleton) provides:

- `currentWM`: "hyprland" | "niri" | "other"
- `isLaptop`, `isArchBased`, `hasBrightnessControl`, `hasKeyboardBacklight`
- Auto-detected on startup via shell script in `Component.onCompleted`

## Compositor Integration

### Hyprland

- **Main config**: `hypr/.config/hypr/hyprland.conf` (sources modular configs from `config/`)
- **Monitor detection**: `config/detect-monitors.sh` symlinks `monitors.conf` based on hostname
  - `Wolverine` → `desktop.conf`
  - `Mentalist` → `laptop.conf`
- **Startup**: `config/startup.conf` launches Quickshell + services (deprecated: waybar/swaync/swayosd)

### Niri

- **Config**: `niri/.config/niri/config.kdl`
- **Workspaces**: Pre-defined with output assignments (e.g., `workspace "Code" {open-on-output "DP-3"}`)
- **Startup**: Quickshell launched via `spawn-at-startup "quickshell"`

Both compositors:

1. Set cursor theme (Bibata-Modern-Ice)
2. Launch Quickshell (replaces waybar/swaync/swayosd)
3. Start clipboard manager (`cliphist`)
4. Autostart apps on specific workspaces

## Development Workflows

### Testing Quickshell

```bash
quickshell  # Run in foreground (check logs for "=== MainService System Info ===")
```

**No compilation needed** - Quickshell directly interprets QML files. Just save and restart.

### Quality Checks

- **No unit tests** - Ensure no lint/error problems exist before committing
- Use `get_errors` tool to check for QML syntax/type errors
- Quickshell auto-fills `.qmlls.ini` with proper paths on launch (no `qmldir` needed)

### System Updates

Use `bin/.local/bin/update.sh`:

- `--quiet`: Minimal output
- `--stream`: Live verbose output
- `--polkit`: Use pkexec for system packages, paru for AUR

### Fish Shell

Primary shell (`fish/.config/fish/config.fish`):

- History per terminal context (ZED_TERM → zed, VSCODE_INJECTION → vscode, etc.)

## Critical Conventions

### 1. Import Patterns

- **Never import from same directory** - No `import "."` needed for local files
- **Module imports only**: Use namespace imports like `import qs.Services.Core`
- Components in the same folder are automatically accessible

### 2. Code Style

- **Prefer concise code** - Always use the least amount of code possible
- Avoid verbose patterns when simpler alternatives exist
- Use arrow functions, ternary operators, and property bindings over imperative code
- always use proper `const` and `let` declarations in JavaScript blocks
- proper local and function naming, no single-letter names

### 3. Service Property Patterns

- **readonly property**: Use for derived/computed values
- **property**: Use for stateful/mutable values
- Example from `NetworkService`:
  ```qml
  readonly property bool ready: internalReady
  property bool wifiRadioEnabled: internalWifiRadioEnabled
  ```

### 4. WM-Agnostic Code

Check compositor before using WM-specific features:

```qml
if (MainService.currentWM === "hyprland") {
    // Hyprland-specific IPC
} else if (MainService.currentWM === "niri") {
    // Niri-specific commands
}
```

### 5. Component Communication

- **Services → Components**: Components import and bind to singleton services
- **Inter-service**: Use Qt signals/slots or shared singleton state
- **External commands**: Use `Process` from Quickshell.Io or IPC

### 6. Wallpaper Management

`WallpaperService` handles per-monitor wallpapers:

- `wallpaperFor(screenName)` returns `{wallpaper: path, mode: "fill"|"fit"|...}`
- AnimatedWallpaper component instantiated per monitor via `Variants`

### 7. Secrets Management

Secrets stored in `.local_secrets/` (gitignored). Reference in configs:

```qml
readonly property string apiKey: Quickshell.env("SECRET_API_KEY") || ""
```

### 8. AI Agent Workflow

- **Always check documentation**: Use project docs or Context7 tool for library references
- **Use sequential thinking**: Apply thinking tool for complex logic and decision-making
- **Leverage memory**: Store and recall important patterns and decisions during development

## Common Tasks

### Adding a New Service

1. Create `Services/Core/MyService.qml` (or `SystemInfo/MyService.qml`)
2. Start with `pragma Singleton` + `import qs.Services.Utils` for Logger
3. Expose via singleton pattern (no explicit registration needed)
4. Import in components: `import qs.Services.Core`

### Adding IPC Command

Edit `Services/Utils/IPC.qml`:

```qml
IpcHandler {
    target: "mytarget"
    function mycommand(arg: string): string {
        Logger.log("IPC", `mycommand called with ${arg}`)
        return "ok"
    }
}
```

### Debugging

- Enable verbose logging: Set `Logger.includeModules: ["MyService"]` in `Logger.qml`
- Check service ready state: `Logger.log("MyService", MainService.ready ? "ready" : "not ready")`

## Technology Stack

- **Shell Framework**: Quickshell (Qt/QML-based)
- **Compositors**: Hyprland, Niri
- **Config Management**: GNU Stow
- **Primary Shell**: Fish
