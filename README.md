<h1 align="center">Obelisk Shell</h1>

<p align="center">
  Modular Wayland dotfiles centered on Quickshell, with Hyprland and Niri support.
</p>

<p align="center">
  <img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=9ccbfb" />
  <img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=d3bfe6" />
  <img alt="QML Lines" src="https://img.shields.io/endpoint?url=https%3A%2F%2Fghloc.vercel.app%2Fapi%2Fanasgets111%2Fdotfiles%2Fbadge%3Ffilter%3D.qml%2524&style=for-the-badge&label=QML%20Lines&labelColor=101418&color=b8dceb" />
  <a href="./LICENSE"><img alt="License: GPLv3" src="https://img.shields.io/badge/License-GPLv3-9ccbfb?style=for-the-badge&labelColor=101418" /></a>
</p>

## Preview

https://github.com/user-attachments/assets/94bd03cf-6e94-4d71-bf62-9ba58eac3954

## Features

- A Wayland bar with compositor-agnostic workspace, monitor, keyboard-layout, and active-window services for Hyprland and Niri.
- Freedesktop notifications, system tray, OSD, application launcher, Polkit agent, and WlSessionLock screen.
- Per-monitor wallpapers with animated transitions, plus the Niri overview wallpaper.
- Audio, privacy, power, brightness, networking, Bluetooth, weather, updates, recording, and input-overlay controls.
- MPRIS media controls with optional Cava visualization.

## Requirements

Deployment requires Git and GNU Stow. The shell requires Quickshell, either Hyprland or Niri, and the `CaskaydiaCove Nerd Font Propo` and `JetBrainsMono Nerd Font Mono` font families.

Desktop integrations use NetworkManager, PipeWire/WirePlumber, BlueZ and `bluez-utils`, UPower, power-profiles-daemon, Polkit, `brightnessctl`, `wl-clipboard`, `libnotify`, and `xdg-terminal-exec`.

Optional features are detected at runtime:

- Screen recording: `gpu-screen-recorder` and `slurp`.
- Input overlay: `showmethekey-cli`.
- Media visualization: `cava`.
- System information: `nvtop`, `lm_sensors`, and `edid-decode`.
- Arch updates: `checkupdates` from `pacman-contrib` and `expac`.
- Clipboard persistence: `cliphist` on Hyprland or `wl-clip-persist` on Niri.
- `hdrshot`: Hyprland, `flock`, `hyprshot`, `satty`, and `wl-copy`.

Adjust package names for your distribution.

## Installation

> [!WARNING]
> Back up any existing dotfiles that share these paths, and review [Configuration](#configuration) before starting a compositor session.

Clone the repository and deploy the core configurations:

```bash
git clone https://github.com/anasgets111/dotfiles.git
cd dotfiles
stow -t "$HOME" home config quickshell hypr niri fish nvim kitty mpv bin
```

Deploy any additional terminal or shell configurations you use:

```bash
stow -t "$HOME" ghostty alacritty foot wezterm nushell
```

Choose either a Hyprland or Niri session; both start Quickshell. QML changes reload automatically.

Remove a deployed package with:

```bash
stow -D -t "$HOME" <package>
```

## Configuration

These are personal dotfiles, not generic compositor defaults. Review them before starting a session:

- Adapt the host-specific Hyprland monitor profiles in [`monitors.lua`](hypr/.config/hypr/config/monitors.lua), or the Niri outputs and workspace assignments in [`config.kdl`](niri/.config/niri/config.kdl).
- Remove unwanted applications from the Hyprland and Niri startup lists.
- Set your wallpaper directory and weather location in [`Settings.qml`](quickshell/.config/quickshell/Config/Settings.qml) before first launch. Runtime settings are persisted in `$XDG_CONFIG_HOME/Obelisk/settings.json`, or `~/.config/Obelisk/settings.json` by default.

## Repository layout

| Path | Contents |
| --- | --- |
| `quickshell/` | Obelisk Shell: QML components, services, panels, shaders, and themes. |
| `hypr/`, `niri/` | Hyprland Lua configuration and Niri KDL configuration. |
| `home/`, `config/` | Shell profile plus shared XDG, Starship, Fastfetch, and application flag configuration. |
| `fish/`, `nushell/`, `nvim/` | Shell and editor configuration. |
| `kitty/`, `ghostty/`, `alacritty/`, `foot/`, `wezterm/` | Terminal emulator configurations. |
| `mpv/` | mpv configuration and scripts. |
| `bin/` | Local utilities, including update, backup, screenshot, logging, and setup helpers. |
| `NixConfig/` | NixOS flake with Wolverine (NVIDIA/Hyprland) and Mentalist (Intel/Niri) hosts. |

## Notes

- Hyprlock, Swaylock, Hypridle, and Swayidle configurations are not included; Quickshell owns locking and idle handling.

## Credits

Thanks to the Linux, Hyprland, Niri, and Quickshell communities, and to the following shells for inspiration:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell/)
- [Noctalia](https://github.com/noctalia-dev/noctalia)
- [caelestia](https://github.com/caelestia-dots/shell)
- [HyprlandDE](https://github.com/ryzendew/HyprlandDE-Quickshell)
