<h1 align="center">Obelisk Shell</h1>

<p align="center">
	<img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=9ccbfb" />
	<img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=d3bfe6" />
	<img alt="QML Lines" src="https://img.shields.io/endpoint?url=https%3A%2F%2Fghloc.vercel.app%2Fapi%2Fanasgets111%2Fdotfiles%2Fbadge%3Ffilter%3D.qml%2524&style=for-the-badge&label=QML%20Lines&labelColor=101418&color=b8dceb" />
  <a href="https://www.gnu.org/licenses/gpl-3.0"><img alt="License: GPLv3" src="https://img.shields.io/badge/License-GPLv3-9ccbfb?style=for-the-badge&labelColor=101418" /></a>
</p>

Modular Wayland desktop dotfiles centered on Quickshell with Hyprland and Niri, managed via GNU Stow.

## Preview

https://github.com/user-attachments/assets/56cffffa-cbbf-4fe1-ad97-7aef8fed57e4

## Quick start

- Symlink into $HOME with Stow:
  - Core: `stow -t ~ home config quickshell hypr niri fish nvim kitty mpv bin`
  - Optional: `stow -t ~ ghostty alacritty foot wezterm nushell`
- Remove: `stow -D -t ~ <package>`
- Test Quickshell: `quickshell` (check logs for `=== MainService System Info ===`).
- Sessions: Hyprland and Niri autostart Quickshell.

## Backed-up configs

- **Core**: quickshell, hypr, niri, fish, kitty
- **Shells**: fish (primary), nushell, bash
- **Terminals**: kitty (primary), ghostty, alacritty, foot, wezterm
- **UI**: Quickshell handles shell, notifications, OSD, lockscreen
- **Idle/Lock**: hypridle/hyprlock (Hyprland), swayidle (Niri)
- **Media**: mpv
- **Bin**: local utility scripts

## Dependencies

- **Required**: quickshell, hyprland or niri, fish, kitty, xdg-terminal-exec, pacman-contrib, gpu-screen-recorder, jq, nmcli, xrandr, libnotify
- **Optional**: hypridle, hyprlock, swayidle, hyprshot, satty, ghostty, alacritty, nvim, mpv, zen-browser

Adjust package names for your distro.

## Features

### Core Services

#### System & Hardware

- [x] Battery monitoring & indicator
- [x] Audio (input/output control)
- [x] Media player controls (MPRIS)
- [x] System info monitoring (CPU, Memory, Disk)
- [x] Monitor management (hotplug, layout, resolution, HDR, VRR)
- [x] Keyboard layout switching & indicator
- [x] Display brightness control
- [x] Keyboard backlight control
- [x] Power management (PPD / TLP profiles)

#### Window Management

- [x] Workspace management (Hyprland/Niri support)
- [x] Active window tracking & display
- [x] Multi-monitor support

#### Desktop Integration

- [x] Notification system (FreeDesktop spec)
- [x] System tray (StatusNotifier protocol)
- [x] App launcher
- [/] Clipboard management
- [x] IPC command system
- [x] Polkit authentication dialog

#### Security & Privacy

- [x] Lock screen (WlSessionLock)
- [x] Idle management & inhibit
- [x] Privacy indicators (mic/camera/screenshare)

#### Connectivity

- [x] Network manager (WiFi/Ethernet, inline connections)
- [x] Bluetooth manager

#### Visual & Media

- [x] Wallpaper management (per-monitor, animated transitions)
- [x] Screen recording (gpu-screen-recorder)
- [x] OSD (on-screen display) system
- [ ] Audio visualizer (cava)
- [x] Input display overlay (keyboard/mouse key display)

#### System

- [x] Power menu
- [x] Package updates (Arch/pacman, notifies by package name)
- [x] Time & date display
- [x] Weather information
- [x] DND mutes third-party audio streams

### UI Components

#### Bar Widgets

- [x] Power menu button
- [x] Update checker (Arch)
- [x] Idle inhibitor toggle
- [x] Keyboard layout indicator
- [x] Battery indicator with PPD profile (laptop)
- [x] App launcher button
- [x] Wallpaper picker button
- [x] Workspace indicators (Normal & Special)
- [x] Active window title
- [x] Privacy indicators
- [x] Volume control with panel
- [x] Screen recorder controls
- [x] Network indicator with panel
- [x] Bluetooth indicator with panel
- [x] System tray
- [x] Date & time with calendar
- [ ] Media player widget (MPRIS controls)
- [ ] System info widget (CPU, Memory, Disk)

#### Overlays & Panels

- [x] Notification popup (actions, images, inline reply, grouping)
- [x] Notification center (DND, history, weather forecast)
- [x] OSD overlay (volume, brightness, etc.)
- [x] Audio panel (devices, streams)
- [x] Network panel (WiFi networks, inline connections)
- [x] Bluetooth panel (devices, pairing)
- [x] Lock screen (per-monitor wallpapers)
- [x] App launcher (grid view, search)
- [x] Wallpaper picker (per-monitor, transitions)
- [x] Idle settings panel
- [x] Input display overlay (draggable)

#### Design System

- [x] Theme (responsive scaling, colors, ultrawide support)
- [x] IconButton component
- [x] Tooltip system
- [x] Panel framework
- [x] Input components
- [x] Toggle components

## Notes

- hyprlock and swaylock are no longer included; Quickshell provides the lock screen.
- Default terminal via `xdg-terminal-exec` is easier for me to swap in all the system.

## Credits

Grateful for Linux/Hyprland/Niri/Quickshell projects and rest of community, learned alot from various existing shells, including:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell/)
- [noctalia](https://github.com/noctalia-dev/noctalia-shell)
- [caelestia](https://github.com/caelestia-dots/shell)
- [HyprlandDE](https://github.com/ryzendew/HyprlandDE-Quickshell)
