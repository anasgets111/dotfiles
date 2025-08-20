<h1 align="center">Quickshell Wayland Shell</h1>

<p align="center">
	<img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=9ccbfb" />
	<img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/anasgets111/dotfiles?style=for-the-badge&labelColor=101418&color=d3bfe6" />
  <a href="https://www.gnu.org/licenses/gpl-3.0"><img alt="License: GPLv3" src="https://img.shields.io/badge/License-GPLv3-9ccbfb?style=for-the-badge&labelColor=101418" /></a>
</p>

Modular Wayland desktop dotfiles centered on Quickshell with Hyprland and Niri, managed via GNU Stow.

## Quick start

- Symlink into $HOME with Stow:
  - Install one package: `stow -t ~ quickshell`
  - Recommended core set:
    - `stow -t ~ home config quickshell hypr niri fish nvim kitty mpv swayidle ghostty alacritty nushell`
  - Optional backups (when not using Quickshell UI/lock):
    - `stow -t ~ swaylock swaync swayosd waybar`
- Remove a package: `stow -D -t ~ <package>`
- Launch Quickshell for testing: `quickshell` (check logs for `=== MainService System Info ===`).
- Sessions:
  - Hyprland autostarts Quickshell (exec-start in `hypr/hyprland.conf`).
  - Niri autostarts Quickshell (spawn-at-startup in `niri/config.kdl`).

## Modules in repo

Core & window managers:

- quickshell (primary UI/runtime)
- hypr, niri

Shells:

- fish (primary), nushell (basic), bash (login; spawns fish when interactive)

Terminals:

- kitty (primary), ghostty, alacritty
- Default terminal switching handled via xdg-terminal-exec

UI components provided by Quickshell:

- Shell, notifications, on-screen-display (OSD), and lockscreen live in Quickshell

Backups kept around (replaced with Quickshell):

- swaync (notifications)
- swayosd (OSD)
- swaylock-effects (lockscreen for Niri)
- waybar (panel; legacy/backup)

Idle/lock by WM:

- Niri: swayidle + swaylock-effects (backup path if not using Quickshell lock)
- Hyprland: hypridle + hyprlock (backup path if not using Quickshell lock)

Screenshots:

- Hyprland: hyprshot
- Niri: native screenshot tool currently used
- satty for annotation/saving

Media/tools:

- mpv

## Dependencies

Main (required):

- quickshell
- hyprland or niri
- fish
- kitty (or your preferred terminal)
- xdg-terminal-exec (default terminal switcher)
- pacman-contrib
- gpu-screen-recorder, jq, nmcli, xrandr, libnotify (notify-send)

Optional (used by configs or as backups):

- hypridle, hyprlock (Hyprland idle/lock)
- swayidle, swaylock-effects (Niri idle/lock)
- swayosd (OSD), swaync (notifications), waybar (panel)
- hyprshot (Hyprland screenshots), satty (annotation)
- ghostty, alacritty, nvim, mpv, zen-browser

Note: Package names above follow Arch/Arch-based naming; adjust for your distro as needed.

## Key files and layout

- `quickshell/.config/quickshell/shell.qml` – ShellRoot; imports services and logs when detection finishes.
- `quickshell/.config/quickshell/services/` – Quickshell services (UPower, Pipewire, etc.).
- `hypr/.config/hypr/` – Modular Hyprland config; sourced by `hyprland.conf` and autostarts Quickshell.
- `niri/.config/niri/config.kdl` – Spawns Quickshell and session helpers; pins workspaces.
- `bin/.local/bin/` – Local scripts like `update.sh`, `RecordingStatus.sh`, `check_battery.sh`.
- `waybar/.config/waybar/` – Legacy Waybar config (not used by default).

## Notes and gotchas

- Waybar is deprecated here; Quickshell provides the UI.
- Ensure tools referenced by scripts are installed (`hyprctl`, `jq`, `gpu-screen-recorder`, `nmcli`, `xrandr`, `notify-send`).
- Default terminal switching is handled via `xdg-terminal-exec`.
- Backups (swaync, swayosd, swaylock-effects, waybar) are kept for fallback and are not the default when Quickshell UI is active.

---

Stow-friendly and minimal by design. Tweak modules to taste and reload your session.
