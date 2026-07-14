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

- Install the core packages with GNU Stow:

  ```bash
  stow -t "$HOME" home config quickshell hypr niri fish nvim kitty mpv bin
  ```

- Install any terminal or shell configs you use:

  ```bash
  stow -t "$HOME" ghostty alacritty foot wezterm nushell
  ```

- Remove a package with `stow -D -t "$HOME" <package>`.
- Choose either a Hyprland or Niri session. Both configurations start Quickshell.
- Quickshell reloads QML changes automatically.

## Repository layout

| Path | Contents |
| --- | --- |
| `quickshell/` | Obelisk Shell: QML components, services, panels, shaders, themes, and greeter. |
| `hypr/`, `niri/` | Hyprland Lua configuration and Niri KDL configuration. |
| `home/`, `config/` | Shell profile plus shared XDG, Starship, Fastfetch, and application flag configuration. |
| `fish/`, `nushell/`, `nvim/` | Shell and editor configuration. |
| `kitty/`, `ghostty/`, `alacritty/`, `foot/`, `wezterm/` | Terminal emulator configurations. |
| `mpv/` | mpv configuration and scripts. |
| `bin/` | Local utilities, including update, backup, screenshot, logging, and setup helpers. |
| `NixConfig/` | NixOS flake with Wolverine (NVIDIA/Hyprland) and Mentalist (Intel/Niri) hosts. |

## Dependencies


The shell needs Quickshell and either Hyprland or Niri. Its enabled services also use NetworkManager (`nmcli`), PipeWire (`wpctl`/`pactl`), UPower, `brightnessctl`, `powerprofilesctl`, `wl-clipboard`, and `notify-send`.

Optional integrations are detected at runtime:

- Screen recording needs `gpu-screen-recorder` and `slurp`.
- The keyboard and mouse input overlay needs `showmethekey-cli`.
- `hdrshot` needs Hyprland, `flock`, `hyprshot`, `satty`, and `wl-copy`.
- The Arch update widget is active only on Arch-based systems.

Adjust package names for your distribution. The default terminal is resolved through `xdg-terminal-exec`.

## Features

### Shell

- A Wayland bar with compositor-agnostic workspace, monitor, keyboard-layout, and active-window services for Hyprland and Niri.
- Freedesktop notifications, system tray, OSD, application launcher, Polkit dialog, and a WlSessionLock lock screen.
- Per-monitor wallpapers with animated transitions, plus the Niri overview wallpaper.
- Audio input/output controls, privacy status, battery and power-profile controls, brightness and keyboard-backlight control, and MPRIS playback controls through IPC.
- Network and Bluetooth management, clipboard persistence, weather, time/date, and Arch package-update notifications.

### Bar, panels, and overlays

- Bar controls for power, updates, idle inhibition, keyboard layout, battery, launcher, wallpapers, workspaces, active window, privacy, audio, recording, networking, Bluetooth, tray, and calendar.
- Panels for audio devices and streams, network connections, Bluetooth devices, notifications, updates, calendar, power, and idle/input-overlay settings.
- A draggable keyboard and mouse overlay when `showmethekey-cli` is installed.
- Region screen recording with `gpu-screen-recorder`.

### Included but not wired into the bar

- `Cava.qml`, a media player service, and system-information services are present, but no Cava, media, or system-information bar widget is currently loaded.

## Notes

- Hyprlock, Swaylock, Hypridle, and Swayidle configurations are not included; Quickshell owns locking and idle handling.

## Credits

Grateful for Linux/Hyprland/Niri/Quickshell projects and rest of community, learned alot from various existing shells, including:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell/)
- [noctalia](https://github.com/noctalia-dev/noctalia-shell)
- [caelestia](https://github.com/caelestia-dots/shell)
- [HyprlandDE](https://github.com/ryzendew/HyprlandDE-Quickshell)
