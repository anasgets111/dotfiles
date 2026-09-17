<h1 align="center">Obelisk Shell</h1>

<p align="center">
  A Lua desktop shell for Wayland — bar, launcher, notifications, OSD, lock screen and wallpapers — built on the <a href="https://github.com/anasgets111/obelisk-engine">Obelisk engine</a>, plus the Arch Linux dotfiles that run it on Hyprland and Niri.
</p>

<p align="center">
  <img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=9ccbfb" />
  <img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=d3bfe6" />
  <img alt="Lua Lines" src="https://img.shields.io/endpoint?url=https%3A%2F%2Fghloc.vercel.app%2Fapi%2Fanasgets111%2Fdotfiles%2Fbadge%3Ffilter%3D.lua%2524&style=for-the-badge&label=Lua%20Lines&labelColor=101418&color=b8dceb" />
  <a href="./LICENSE"><img alt="License: GPLv3" src="https://img.shields.io/badge/License-GPLv3-9ccbfb?style=for-the-badge&labelColor=101418" /></a>
</p>

## Preview

<!-- Stills: save shots as docs/preview-bar.png and docs/preview-panels.png, then drop these markers.
<p align="center">
  <img alt="Bar, launcher and notifications" src="docs/preview-bar.png" width="49%" />
  <img alt="Panels and wallpaper picker" src="docs/preview-panels.png" width="49%" />
</p>
-->

https://github.com/user-attachments/assets/038ee763-d7b6-4df9-9f79-2f131d4f0dcd

## The shell

- [`obelisk/`](obelisk/.config/obelisk/shell.lua) is the shell. The engine ships the `obelisk` binary, Lua API and capabilities; this repo is only my Lua on top of them.
- Hyprland and Niri start it at login and bind keys to `obelisk toggle` and `obelisk call`.
- Saving a `.lua` under `~/.config/obelisk` reloads it in place. A broken edit keeps the last working shell and shows the error in the bar.

| Area | Includes |
| --- | --- |
| Bar | Workspaces, Hyprland scratchpads, active window, keyboard layout, tray, clock, weather, system info, privacy, battery, volume, network, Bluetooth, updates, recording |
| Panels | Audio mixer, network, Bluetooth, media, calendar, notification history, pacman and dev-tool updates, recording, power |
| Launcher | Fuzzy app search, arithmetic, currency conversion |
| Overlays | Notifications, OSD, polkit agent, Bluetooth pairing, lock screen |
| Idle | Displays off, lock, suspend, with a settings modal. Replaces Hyprlock, Hypridle, Swaylock and Swayidle |
| Wallpaper | Per output, shader transitions (`disc`, `pixelate`, `portal`, `stripes`, `wipe`), picker, Niri overview backdrop |
| Power | Charger OSD, low-battery notifications, automatic suspend |

## Requirements

| For | Needs |
| --- | --- |
| Shell | [Obelisk engine](https://github.com/anasgets111/obelisk-engine) — the `obelisk` binary |
| Compositor | Hyprland 0.56+ (Lua config) or Niri |
| Deployment | Arch Linux, Git, GNU Stow |
| Fonts | CaskaydiaCove Nerd Font Propo, JetBrainsMono Nerd Font Mono, Noto Sans, Noto Sans CJK, Noto Color Emoji |
| Shell helpers | `curl` (weather, currency), `libnotify`, `wl-clipboard`, `xdg-utils`, `gpu-screen-recorder` and `slurp` (recording) |
| Screenshots | [`hdrshot`](bin/.local/bin/hdrshot), the `Print` script: `hyprshot` capture, `satty` annotation, `wl-copy`, `flock` |

## Installation

> [!WARNING]
> Move any existing dotfiles aside first — stow refuses to overwrite them — and read [Configuration](#configuration) for the settings that are mine, not yours.

**0. [Install the engine](https://github.com/anasgets111/obelisk-engine).** Nothing here runs without it.

**1. Stow the shell and its compositors.**

```bash
git clone https://github.com/anasgets111/dotfiles.git
cd dotfiles
stow -t "$HOME" obelisk hypr niri home config xdg-desktop-portal bin
```

**2. Stow the rest, as you like.**

```bash
stow -t "$HOME" fish nvim kitty mpv                     # shell, editor, terminal, player
stow -t "$HOME" ghostty alacritty foot wezterm nushell   # alternative terminals and shells
```

Roll a package back with `stow -D -t "$HOME" <package>`. `home` installs `~/.stowrc`, which points stow at this clone — edit it, and `stow`/`stow -D` work from any directory without `-t`. [`arch-install.sh`](bin/.local/bin/arch-install.sh) does packages and stow in one go for my two machines.

## Keybinds

A subset; the full sets live in [`keybinds.lua`](hypr/.config/hypr/config/keybinds.lua) (Hyprland) and the `binds` block of [`config.kdl`](niri/.config/niri/config.kdl) (Niri).

| Keys | Action |
| --- | --- |
| `Super+Space` | Launcher |
| `Super+Shift+W` | Wallpaper picker |
| `Super+Ctrl+P` | Idle settings |
| `Super+L` | Lock (`loginctl lock-session`) |
| `Print` / `Ctrl+Print` | Screenshot region / output |
| `Shift+Print` | Start or stop recording |
| `Super+M` | Mute microphone |

## Configuration

| What | Where |
| --- | --- |
| Monitors, including an ICC profile | [`monitors.lua`](hypr/.config/hypr/config/monitors.lua), or outputs in [`config.kdl`](niri/.config/niri/config.kdl) |
| Startup apps | [`startup.lua`](hypr/.config/hypr/config/startup.lua), `spawn-at-startup` in `config.kdl`. Niri needs an absolute path to the `obelisk` binary |
| Wallpaper folder | `wallpaper.FOLDER` in [`lib/wallpaper.lua`](obelisk/.config/obelisk/lib/wallpaper.lua) |
| Colours, sizes, fonts | [`config/theme.lua`](obelisk/.config/obelisk/config/theme.lua), the `fonts` chain in [`shell.lua`](obelisk/.config/obelisk/shell.lua) |
| Update-panel tools | [`config/dev_tools.lua`](obelisk/.config/obelisk/config/dev_tools.lua) |
| Editor stubs | `workspace.library` in [`.luarc.json`](.luarc.json), pointing at your engine checkout's `lua-meta` |
| Weather location | Derived from the system timezone |
| Runtime state | `~/.local/state/obelisk/state.json` |

## Repository layout

| Path | Contents |
| --- | --- |
| `obelisk/` | `components/`, `config/`, `lib/`, `modules/` and transition `shaders/` |
| `hypr/`, `niri/` | Compositors: Hyprland Lua, Niri KDL |
| `home/`, `config/` | Shell profile, `.stowrc`, XDG, Starship, Fastfetch, app flags |
| `fish/`, `nushell/`, `nvim/` | Shells and editor |
| `kitty/`, `ghostty/`, `alacritty/`, `foot/`, `wezterm/` | Terminals |
| `mpv/` | mpv config and scripts |
| `bin/` | Install, backup and screenshot scripts |
| `NixConfig/` | Inactive NixOS flake for an NVIDIA/Hyprland and an Intel/Niri machine |

## Credits

Thanks to the Linux, Hyprland, Niri and Quickshell communities, and to these shells for inspiration:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell/)
- [Noctalia](https://github.com/noctalia-dev/noctalia)
- [caelestia](https://github.com/caelestia-dots/shell)
- [HyprlandDE](https://github.com/ryzendew/HyprlandDE-Quickshell)
