<h1 align="center">Mantle Shell</h1>

<p align="center">
  Lua desktop shell for Wayland built on the <a href="https://github.com/anasgets111/mantle">Mantle engine</a>, with Arch Linux dotfiles for Hyprland and Niri.
</p>

<p align="center">
  <img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=9ccbfb" />
  <img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=d3bfe6" />
  <img alt="Lua Lines" src="https://img.shields.io/endpoint?url=https%3A%2F%2Fghloc.vercel.app%2Fapi%2Fanasgets111%2Fdotfiles%2Fbadge%3Ffilter%3D.lua%2524&style=for-the-badge&label=Lua%20Lines&labelColor=101418&color=b8dceb" />
  <a href="./LICENSE"><img alt="License: GPLv3" src="https://img.shields.io/badge/License-GPLv3-9ccbfb?style=for-the-badge&labelColor=101418" /></a>
</p>

## Preview

https://github.com/user-attachments/assets/038ee763-d7b6-4df9-9f79-2f131d4f0dcd

## The shell

- [`mantle/`](mantle/.config/mantle/shell.lua) holds the shell config. The upstream engine provides the `mantle` binary, Lua API, and capabilities.
- Hyprland and Niri launch it at login and bind shortcuts to `mantle toggle` and `mantle call`.
- Saving any `.lua` file under `~/.config/mantle` reloads the shell in place. An invalid edit keeps the active scene running and surfaces the error in the bar.

| Area | Includes |
| --- | --- |
| Bar | Workspaces, Hyprland scratchpads, active window, keyboard layout, tray, clock, weather, system info, privacy, battery, volume, network, Bluetooth, updates, recording |
| Panels | Audio mixer, network, Bluetooth, media, calendar, notification history, pacman and dev-tool updates, recording, power |
| Launcher | Fuzzy app search, arithmetic, currency conversion |
| Overlays | Notifications, OSD, polkit agent, Bluetooth pairing, lock screen |
| Idle | Displays off, lock, suspend, with a settings modal. Replaces Hyprlock, Hypridle, Swaylock, and Swayidle |
| Wallpaper | Per output, shader transitions (`disc`, `pixelate`, `portal`, `stripes`, `wipe`), picker, Niri overview backdrop |
| Power | Charger OSD, low-battery notifications, automatic suspend |

## Requirements

| For | Needs |
| --- | --- |
| Shell | [Mantle engine](https://github.com/anasgets111/mantle) binary |
| Compositor | Hyprland 0.56+ (Lua config) or Niri |
| Deployment | Arch Linux, Git, GNU Stow |
| Fonts | CaskaydiaCove Nerd Font Propo, Noto Sans, Noto Sans CJK JP, Noto Color Emoji |
| Shell helpers | `curl`, `libnotify`, `wl-clipboard`, `xdg-utils`, `gpu-screen-recorder`, `slurp` |
| Screenshots | [`hdrshot`](bin/.local/bin/hdrshot) using `hyprshot`, `satty`, `wl-copy`, `flock` |

## Installation

> [!WARNING]
> Back up existing dotfiles first; GNU Stow will not overwrite conflicting files. Review [Configuration](#configuration) for hardware and user-specific paths.

1. **[Install the engine](https://github.com/anasgets111/mantle).** Required before launching the shell.

2. **Stow core packages.**

```bash
git clone https://github.com/anasgets111/dotfiles.git
cd dotfiles
stow -t "$HOME" mantle hypr niri home config xdg-desktop-portal bin
```

3. **Stow optional packages.**

```bash
stow -t "$HOME" fish nvim kitty mpv                     # shell, editor, terminal, player
stow -t "$HOME" ghostty alacritty foot wezterm nushell   # alternative terminals and shells
```

Unstow packages with `stow -D -t "$HOME" <package>`. The `home` package provides `~/.stowrc` pointing at this repository, allowing `stow` and `stow -D` to run from any directory without `-t`. [`arch-install.sh`](bin/.local/bin/arch-install.sh) automates the full Arch install and stow setup for my machines.

## Keybinds

Core shortcuts. Full mappings live in [`keybinds.lua`](hypr/.config/hypr/config/keybinds.lua) for Hyprland and the `binds` block of [`config.kdl`](niri/.config/niri/config.kdl) for Niri.

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
| Startup apps | [`startup.lua`](hypr/.config/hypr/config/startup.lua), or `spawn-at-startup` in [`config.kdl`](niri/.config/niri/config.kdl). Niri requires an absolute path to `mantle` |
| Wallpaper folder | `wallpaper.FOLDER` in [`lib/wallpaper.lua`](mantle/.config/mantle/lib/wallpaper.lua) |
| Colours, sizes, fonts | [`config/theme.lua`](mantle/.config/mantle/config/theme.lua), `fonts` table in [`shell.lua`](mantle/.config/mantle/shell.lua) |
| Update-panel tools | [`config/dev_tools.lua`](mantle/.config/mantle/config/dev_tools.lua) |
| Editor stubs | `workspace.library` in [`.luarc.json`](.luarc.json), pointing at the engine's `lua-meta` |
| Weather location | Derived from system timezone |
| Runtime state | `~/.local/state/mantle/state.json` |

## Repository layout

| Path | Contents |
| --- | --- |
| `mantle/` | `components/`, `config/`, `lib/`, `modules/`, and transition `shaders/` |
| `hypr/`, `niri/` | Compositor configurations for Hyprland and Niri |
| `home/`, `config/` | Shell profile, `.stowrc`, XDG, Starship, Fastfetch, app flags |
| `fish/`, `nushell/`, `nvim/` | Shells and editor |
| `kitty/`, `ghostty/`, `alacritty/`, `foot/`, `wezterm/` | Terminals |
| `mpv/` | mpv config and scripts |
| `bin/` | Install, backup, and screenshot scripts |
| `NixConfig/` | Inactive NixOS flake for an NVIDIA/Hyprland and an Intel/Niri machine |

## Credits

Inspiration and reference shells:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell/)
- [Noctalia](https://github.com/noctalia-dev/noctalia)
- [caelestia](https://github.com/caelestia-dots/shell)
- [HyprlandDE](https://github.com/ryzendew/HyprlandDE-Quickshell)
