---
description: Quickshell QML patterns and conventions
globs: ["quickshell/**/*.qml", "quickshell/**/*.js"]
alwaysApply: false
---

# Quickshell QML Architecture

**Location**: `quickshell/.config/quickshell/`

## Directory Structure

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

## Key Patterns

### 1. Component Behavior Pragma

**ALWAYS** use at the top of component files:

```qml
pragma ComponentBehavior: Bound
```

### 2. Singleton Services

All services are QML singletons. Import with namespace:

```qml
import qs.Services.Core        // Core services (Audio, Network, etc.)
import qs.Services.SystemInfo  // SystemInfo services (Time, Weather, etc.)
import qs.Services.Utils       // IPC, Logger
import qs.Services.WM          // Workspace management
```

### 3. Import Rules

- **Never import from same directory** - No `import "."` needed for local files
- **Module imports only**: Use namespace imports like `import qs.Services.Core`
- Components in the same folder are automatically accessible

### 4. Lazy Loading Pattern

Use `LazyLoader` for expensive components:

```qml
LazyLoader {
    active: condition
    component: SomeComponent { ... }
}
```

### 5. Multi-Monitor Handling

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

### 6. Logging Convention

Use `Logger.log("ModuleName", "message")` for debugging:

```qml
import qs.Services.Utils  // Provides Logger singleton
Logger.log("NetworkService", `Connected to ${ssid}`)
```

### 7. Responsive Theming

`Config/Theme.qml` calculates `baseScale` from monitor diagonal + DPR:

```qml
import qs.Config  // Provides Theme singleton
width: Theme.baseScale * 200
```

### 8. Service Property Patterns

- **readonly property**: Use for derived/computed values
- **property**: Use for stateful/mutable values

```qml
readonly property bool ready: internalReady
property bool wifiRadioEnabled: internalWifiRadioEnabled
```

## IPC System

Centralized in `Services/Utils/IPC.qml`:

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

## Component Communication

- **Services → Components**: Components import and bind to singleton services
- **Inter-service**: Use Qt signals/slots or shared singleton state
- **External commands**: Use `Process` from Quickshell.Io or IPC

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
