# Quickshell Project Structure

## 📁 Directory Tree

```
quickshell/
│
├── 📄 Configuration Files
│   ├── .qmlls.ini              # QML Language Server config
│   ├── .qmlformat.ini          # QML formatter config
│   ├── README                  # Project README
│   └── shell.qml               # Main shell entry point
│
├── 🎨 Assets/
│   ├── 3.jpg                   # Wallpaper image
│   ├── ColorScheme/            # Theme color schemes
│   │   ├── Catppuccin.json
│   │   ├── Dracula.json
│   │   ├── Gruvbox.json
│   │   ├── Nord.json
│   │   ├── Obelisk (default).json
│   │   ├── Rosepine.json
│   │   ├── Solarized.json
│   │   └── Tokyo Night.json
│   └── Matugen/                # Material You color generation
│       ├── matugen.base.toml
│       ├── matugen.toml
│       └── templates/
│
├── 🧩 Components/              # Reusable UI components
│   ├── AnimatedWallpaper.qml
│   ├── ExpandingPill.qml
│   ├── FillBar.qml
│   ├── IconButton.qml
│   ├── LockContent.qml
│   ├── LockScreen.qml
│   ├── PulseFlash.qml
│   ├── SearchGridPanel.qml
│   ├── Slider.qml
│   └── Tooltip.qml
│
├── ⚙️  Config/                  # Configuration modules
│   ├── Settings.qml
│   └── Theme.qml
│
├── 📚 Docs/                    # Documentation
│   ├── notes.md
│   ├── Notifcations.md
│   ├── QS-wayland-docs.md
│   ├── QSdocs.md
│   └── quickshell-io.md
│
├── 🔧 Modules/                 # Feature modules
│   ├── AppLauncher/
│   │   └── Launcher.qml
│   ├── Bar/                    # Status bar components
│   │   ├── ActiveWindow.qml
│   │   ├── ArchChecker.qml
│   │   ├── Bar.qml
│   │   ├── BatteryIndicator.qml
│   │   ├── BluetoothIndicator.qml
│   │   ├── Cava.qml
│   │   ├── CenterSide.qml
│   │   ├── DateTimeDisplay.qml
│   │   ├── IdleInhibitor.qml
│   │   ├── KeyboardLayoutIndicator.qml
│   │   ├── LeftSide.qml
│   │   ├── MinimalCalendar.qml
│   │   ├── NetworkIndicator.qml
│   │   ├── NiriWorkspaces.qml
│   │   ├── NormalWorkspaces.qml
│   │   ├── PowerMenu.qml
│   │   ├── PrivacyIndicator.qml
│   │   ├── RightSide.qml
│   │   ├── RoundCorner.qml
│   │   ├── ScreenRecorder.qml
│   │   ├── SpecialWorkspaces.qml
│   │   ├── SysTray.qml
│   │   ├── Volume.qml
│   │   └── WallpaperButton.qml
│   ├── Notification/           # Notification system
│   │   ├── CardStyling.qml
│   │   ├── NotificationCard.qml
│   │   ├── NotificationPopup.qml
│   │   └── StandardButton.qml
│   ├── OSD/                    # On-Screen Display
│   │   └── Toasts.qml
│   └── WallpaperPicker/
│       └── WallpaperPicker.qml
│
├── 🔌 Services/                # Backend services
│   ├── MainService.qml
│   ├── Core/                   # Core system services
│   │   ├── AudioService.qml
│   │   ├── BatteryService.qml
│   │   ├── BluetoothService.qml
│   │   ├── BrightnessService.qml
│   │   ├── ClipboardLiteService.qml
│   │   ├── ClipboardService.qml
│   │   ├── FileSystemService.qml
│   │   ├── IdleService.qml
│   │   ├── KeyboardBacklightService.qml
│   │   ├── LockService.qml
│   │   ├── MediaService.qml
│   │   ├── NetworkService.qml
│   │   ├── PowerManagementService.qml
│   │   ├── SystemTrayService.qml
│   │   └── WallpaperService.qml
│   ├── SystemInfo/             # System information services
│   │   ├── NotificationService.qml
│   │   ├── OSDService.qml
│   │   ├── PrivacyService.qml
│   │   ├── ScreenRecordingService.qml
│   │   ├── SystemInfoService.qml
│   │   ├── TimeService.qml
│   │   ├── UpdateService.qml
│   │   └── WeatherService.qml
│   ├── Utils/                  # Utility services
│   │   ├── Fzf.qml
│   │   ├── IPC.qml
│   │   ├── Logger.qml
│   │   ├── Markdown2Html.qml
│   │   └── Utils.qml
│   └── WM/                     # Window Manager integration
│       ├── KeyboardLayoutService.qml
│       ├── MonitorService.qml
│       ├── WorkspaceService.qml
│       └── Impl/
│
└── 🎨 Shaders/                 # Graphics shaders
    ├── frag/                   # Fragment shaders
    └── qsb/                    # Qt shader bytecode

```

## 🏗️ Architecture Overview

### Entry Point

- `shell.qml` - Main application entry point

### Core Layers

1. **Services Layer** (`Services/`)

   - Core system integration (audio, battery, network, etc.)
   - System information providers
   - Utility services (logging, IPC, etc.)
   - Window manager integration

2. **Modules Layer** (`Modules/`)

   - Bar - Status bar with various widgets
   - AppLauncher - Application launcher
   - Notification - Notification system
   - OSD - On-screen display
   - WallpaperPicker - Wallpaper selection

3. **Components Layer** (`Components/`)

   - Reusable UI components
   - Common widgets and controls

4. **Configuration Layer** (`Config/`)
   - Settings management
   - Theme configuration

### Resources

- **Assets** - Images, color schemes, templates
- **Shaders** - Graphics effects
- **Docs** - Documentation and notes

## 📊 Module Breakdown

### Bar Components (19 modules)

- Window management (ActiveWindow, Workspaces)
- System indicators (Battery, Network, Bluetooth)
- Media & Audio (Volume, Cava)
- Utilities (Calendar, DateTime, KeyboardLayout)
- System tools (PowerMenu, ScreenRecorder, IdleInhibitor)

### Services Categories

#### Core Services (15)

Audio, Battery, Bluetooth, Brightness, Clipboard, FileSystem, Idle, Keyboard Backlight, Lock, Media, Network, Power Management, System Tray, Wallpaper

#### System Info Services (8)

Notification, OSD, Privacy, Screen Recording, System Info, Time, Update, Weather

#### Utility Services (5)

Fzf, IPC, Logger, Markdown2Html, Utils

#### WM Services (3)

Keyboard Layout, Monitor, Workspace

## 🎨 Theming

8 pre-configured color schemes available in `Assets/ColorScheme/`:

- Catppuccin
- Dracula
- Gruvbox
- Nord
- Obelisk (default)
- Rosepine
- Solarized
- Tokyo Night

Plus Material You color generation via Matugen.
