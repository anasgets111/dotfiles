<h1 align="center">Obelisk Shell</h1>

<p align="center">
	<img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=9ccbfb" />
	<img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=d3bfe6" />
  <a href="https://www.gnu.org/licenses/gpl-3.0"><img alt="License: GPLv3" src="https://img.shields.io/badge/License-GPLv3-9ccbfb?style=for-the-badge&labelColor=101418" /></a>
</p>

Modular Wayland desktop dotfiles centered on Quickshell with Hyprland and Niri, managed via GNU Stow.

## Quick start

- Symlink into $HOME with Stow:
  - Core: `stow -t ~ home config quickshell hypr niri fish nvim kitty mpv swayidle ghostty alacritty nushell`
  - Optional: `stow -t ~ swaylock swaync swayosd waybar`
- Remove: `stow -D -t ~ <package>`
- Test Quickshell: `quickshell` (check logs for `=== MainService System Info ===`).
- Sessions: Hyprland and Niri autostart Quickshell.

## Backed-up configs

- **Core**: quickshell, hypr, niri, fish, kitty
- **Shells**: fish (primary), nushell, bash
- **Terminals**: kitty (primary), ghostty, alacritty
- **UI**: Quickshell handles shell, notifications, OSD, lockscreen
- **Backups**: swaync, swayosd, swaylock-effects, waybar (for fallback)
- **Idle/Lock**: hypridle/hyprlock (Hyprland), swayidle/swaylock-effects (Niri)
- **Media**: mpv

## Dependencies

- **Required**: quickshell, hyprland or niri, fish, kitty, xdg-terminal-exec, pacman-contrib, gpu-screen-recorder, jq, nmcli, xrandr, libnotify
- **Optional**: hypridle, hyprlock, swayidle, swaylock-effects, swayosd, swaync, waybar, hyprshot, satty, ghostty, alacritty, nvim, mpv, zen-browser

Adjust package names for your distro.

## Goals

### TODO

- Current state of back-end services
  - [x] Battery
  - [x] Sound
  - [x] Media controls
  - [x] Notifications
  - [x] OSD (Toast)
  - [x] Lockscreen
  - [x] Screen Recording
  - [x] System Info and Monitor (CPU, Memory, Disk)
  - [x] Workspaces (Hyprland/niri)
  - [x] Idle Inhibit
  - [x] Power Menu
  - [x] Arch Updater
  - [x] Monitor handling (hotplug, layout, resolution,hdr,vrr)
  - [x] Keyboard Layout Indicator
  - [x] Wallpaper Management with multiple screens
  - [x] Clipboard Management
  - [ ] App Launcher
  - [x] Time and Calendar
  - [x] Weather
  - [x] Bluetooth
  - [ ] Brightness for monitors and keyboards
  - [x] IPC
- and for the front-end
  - [x] IconButton
  - [x] Tooltip
  - [/] Theme
  - [ ] Menu
  - [ ] OSD Slider
  - [ ] OSD Messages
  - [/] Notification Popup
    - [ ] Actions
    - [ ] Images
    - [ ] Icons
    - [ ] Inline replies
    - [ ] Urgency
    - [ ] Rich content
    - [ ] Grouping
  - [ ] Notification Center
  - [/] Lockscreen
  - [ ] Sound Panel
  - [x] Sound Widget
  - [ ] Wifi Panel
  - [ ] Wifi Widget
  - [ ] Bluetooth Panel
  - [ ] Bluetooth Widget

## Notes

- Waybar, swaync, swayosd, hyprlock, swaylock are all deprecated; Quickshell provides UI.
- Default terminal via `xdg-terminal-exec` is easier for me to swap in all the system.

## Credits

Grateful for Linux/Hyprland/Niri/Quickshell projects and rest of community, learned alot from various existing shells, including:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell/)
- [noctalia](https://github.com/noctalia-dev/noctalia-shell)
- [caelestia](https://github.com/caelestia-dots/shell)
- [HyprlandDE](https://github.com/ryzendew/HyprlandDE-Quickshell)
