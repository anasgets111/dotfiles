<h1 align="center">Obelisk Shell</h1>

<p align="center">
  Arch Linux dotfiles for Hyprland and Niri, with a Lua desktop shell built on the <a href="https://github.com/anasgets111/obelisk-engine">Obelisk engine</a>.
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

- [`obelisk/`](obelisk/.config/obelisk/shell.lua) is my desktop shell, a Lua config for the [Obelisk engine](https://github.com/anasgets111/obelisk-engine). The engine provides the `obelisk` binary, Lua API and capabilities; this repo holds only the Lua.
- Hyprland and Niri start it at login and bind keys to `obelisk toggle` and `obelisk call`.
- Saving a `.lua` under `~/.config/obelisk` reloads it in place. A broken edit keeps the last working shell and shows the error in the bar.

## Features

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
| Deployment | Arch Linux, Git, GNU Stow |
| Compositor | Hyprland 0.56+ (Lua config) or Niri |
| Shell | [Obelisk engine](https://github.com/anasgets111/obelisk-engine), installed per its README |
| Fonts | CaskaydiaCove Nerd Font Propo, JetBrainsMono Nerd Font Mono, Noto Sans, Noto Sans CJK, Noto Color Emoji |
| Shell helpers | `curl` (weather, currency), `libnotify`, `wl-clipboard`, `xdg-utils`, `gpu-screen-recorder` and `slurp` (recording) |
| `hdrshot` | Hyprland, `hyprshot`, `satty`, `flock`, `wl-copy` |

## Installation

> [!WARNING]
> Back up existing dotfiles on these paths and read [Configuration](#configuration) before starting a session.

```bash
git clone https://github.com/anasgets111/dotfiles.git
cd dotfiles
stow -t "$HOME" home config xdg-desktop-portal obelisk hypr niri fish nvim kitty mpv bin
stow -t "$HOME" ghostty alacritty foot wezterm nushell   # optional terminals and shells
```

- `home` installs `~/.stowrc`, pointing stow at `/mnt/Work/1Progs/Dots`. Edit it if you cloned elsewhere; then `stow <package>` and `stow -D <package>` work from any directory.
- `bin/.local/bin/arch-install.sh` installs the packages and stows these directories for this repo's two hosts.

## Keybinds

| Keys | Action |
| --- | --- |
| `Super+Space` | Launcher |
| `Super+Shift+W` | Wallpaper picker |
| `Super+Ctrl+P` | Idle settings |
| `Super+L` | Lock (`loginctl lock-session`) |
| `Shift+Print` | Start or stop recording |
| `Super+M` | Mute microphone |

## Configuration

Personal settings to change first:

| What | Where |
| --- | --- |
| Monitors, including Wolverine's ICC profile | [`monitors.lua`](hypr/.config/hypr/config/monitors.lua), or outputs in [`config.kdl`](niri/.config/niri/config.kdl) |
| Startup apps | [`startup.lua`](hypr/.config/hypr/config/startup.lua), `spawn-at-startup` in `config.kdl`. Both start `obelisk` from `~/.local/share/cargo/bin`, Niri by an absolute `/home/anas` path |
| Wallpaper folder | `wallpaper.FOLDER` in [`lib/wallpaper.lua`](obelisk/.config/obelisk/lib/wallpaper.lua) |
| Colours, sizes, fonts | [`config/theme.lua`](obelisk/.config/obelisk/config/theme.lua), the `fonts` chain in [`shell.lua`](obelisk/.config/obelisk/shell.lua) |
| Update-panel tools | [`config/dev_tools.lua`](obelisk/.config/obelisk/config/dev_tools.lua) |
| Editor stubs | [`.luarc.json`](.luarc.json), reading `lua-meta` from `/mnt/Work/0Coding/1Rust/obelisk-shell` |
| Weather location | Derived from the system timezone |
| Runtime state | `~/.local/state/obelisk/state.json` |

## Repository layout

| Path | Contents |
| --- | --- |
| `obelisk/` | Obelisk shell: `components/`, `config/`, `lib/`, `modules/` and transition `shaders/` |
| `hypr/`, `niri/` | Hyprland Lua and Niri KDL configuration |
| `home/`, `config/` | Shell profile, `.stowrc`, and shared XDG, Starship, Fastfetch and app-flag configuration |
| `fish/`, `nushell/`, `nvim/` | Shell and editor configuration |
| `kitty/`, `ghostty/`, `alacritty/`, `foot/`, `wezterm/` | Terminal configuration |
| `mpv/` | mpv configuration and scripts |
| `bin/` | Install, backup and screenshot scripts |
| `NixConfig/` | Inactive NixOS flake for the Wolverine (NVIDIA, Hyprland) and Mentalist (Intel, Niri) hosts |

## Credits

Thanks to the Linux, Hyprland, Niri and Quickshell communities, and to these shells for inspiration:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell/)
- [Noctalia](https://github.com/noctalia-dev/noctalia)
- [caelestia](https://github.com/caelestia-dots/shell)
- [HyprlandDE](https://github.com/ryzendew/HyprlandDE-Quickshell)
