<h1 align="center">Obelisk Shell</h1>

<p align="center">
  Arch Linux dotfiles for Hyprland and Niri, with a Lua desktop shell built on the <a href="https://github.com/anasgets111/obelisk-shell">Obelisk framework</a>.
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

[`obelisk/`](obelisk/.config/obelisk/shell.lua) is my desktop shell, written as a Lua config for the [Obelisk framework](https://github.com/anasgets111/obelisk-shell). The framework provides the `obelisk` binary, the Lua API and the system capabilities; this repo holds only the Lua. Hyprland and Niri start `obelisk` at login and bind keys to `obelisk toggle` and `obelisk call`.

Saving any `.lua` file under `~/.config/obelisk` reloads the shell in place. A broken edit keeps the last working shell up and shows the error in the bar.

## Features

- Bar with workspaces, Hyprland scratchpads, active window, keyboard layout, tray, clock, weather, system info, privacy, battery, volume, network, Bluetooth, updates and screen-recording indicators.
- Dropdown panels for audio mixing, network, Bluetooth, media, calendar, notification history, pacman and developer-tool updates, recording, and power.
- Launcher with fuzzy app search, arithmetic and currency conversion.
- Notifications, OSD, polkit agent, Bluetooth pairing prompt and a lock screen.
- Three-stage idle handling (displays off, lock, suspend) with its own settings modal.
- Per-output wallpapers with shader transitions (`disc`, `pixelate`, `portal`, `stripes`, `wipe`), a picker, and a Niri overview backdrop.
- Charger OSD, low-battery notifications and automatic suspend.

## Requirements

| For | Needs |
| --- | --- |
| Deployment | Arch Linux, Git, GNU Stow |
| Compositor | Hyprland 0.56+ (Lua config) or Niri |
| Shell | [Obelisk framework](https://github.com/anasgets111/obelisk-shell), installed per its README |
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

`home` installs `~/.stowrc`, which points stow at `/mnt/Work/1Progs/Dots`. Edit it if you cloned elsewhere; after that, `stow <package>` and `stow -D <package>` work from any directory.

Start a Hyprland or Niri session. For this repo's two hosts, `bin/.local/bin/arch-install.sh` installs the packages and stows these directories.

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

These are personal dotfiles. Change these before a first session:

| What | Where |
| --- | --- |
| Monitors, including Wolverine's ICC profile | [`hypr/.config/hypr/config/monitors.lua`](hypr/.config/hypr/config/monitors.lua), or the outputs in [`config.kdl`](niri/.config/niri/config.kdl) |
| Startup apps | [`startup.lua`](hypr/.config/hypr/config/startup.lua) and `spawn-at-startup` in `config.kdl`. Both start `obelisk` from `~/.local/share/cargo/bin`, Niri by an absolute `/home/anas` path. |
| Wallpaper folder | `wallpaper.FOLDER` in [`lib/wallpaper.lua`](obelisk/.config/obelisk/lib/wallpaper.lua) |
| Colours, sizes, fonts | [`config/theme.lua`](obelisk/.config/obelisk/config/theme.lua) (Catppuccin Mocha) and the `fonts` chain in [`shell.lua`](obelisk/.config/obelisk/shell.lua) |
| Tools in the update panel | [`config/dev_tools.lua`](obelisk/.config/obelisk/config/dev_tools.lua) |
| Editor stubs | [`.luarc.json`](.luarc.json) loads `lua-meta` from a framework checkout at `/mnt/Work/0Coding/1Rust/obelisk-shell` |

Weather finds its location from the system timezone. Runtime state (wallpapers, weather cache, idle settings) persists in `~/.local/state/obelisk/state.json`.

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

The shell owns locking and idle, so there is no Hyprlock, Swaylock, Hypridle or Swayidle configuration.

## Credits

Thanks to the Linux, Hyprland, Niri and Quickshell communities, and to these shells for inspiration:

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell/)
- [Noctalia](https://github.com/noctalia-dev/noctalia)
- [caelestia](https://github.com/caelestia-dots/shell)
- [HyprlandDE](https://github.com/ryzendew/HyprlandDE-Quickshell)
