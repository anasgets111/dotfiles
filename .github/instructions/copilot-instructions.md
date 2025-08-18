---
applyTo: "**"
---

# Copilot instructions for Dotfiles & Quickshell Workspace

This repo contains dotfiles for a modular Wayland desktop centered on Quickshell (QML) with Hyprland and Niri, managed with GNU Stow.

## Big picture

- Quickshell is the UI/runtime. Entrypoint: `quickshell/.config/quickshell/shell.qml`.
  - Services live in `quickshell/.config/quickshell/services/`.
- Window managers: both Hyprland and Niri are supported.
  - Niri autostarts Quickshell via `niri/.config/niri/config.kdl` (spawn-at-startup).
  - Hyprland is modular under `hypr/.config/hypr/` and sourced by `hyprland.conf` and also autostarts Quickshell (exec-start).
- Waybar deprecated.
- current terminal in use is `kitty`, with `alacritty` and `ghostty` configs available.
- current shell is `fish`, with somewhat working `nushell` config, with basrc running fish when interactive so login shell stays bash.
- the goal is to get quickshell working instead of relying on things like swayosd, swaync, and lock screens.

## Key files

- `quickshell/.config/quickshell/shell.qml` – ShellRoot; imports `./services` and connects `MainService.detectionFinished` for logging.
- `quickshell/.config/quickshell/.qmlls.ini` – QML tooling/import paths (e.g., `/usr/lib/qt6/qml`) we don't edit it.
- `waybar/.config/waybar/{config,modules.jsonc}` – Hyprland and custom JSON modules wired to local scripts.
- Scripts: `bin/.local/bin/{ScreenRecording.sh,RecordingStatus.sh,check_battery.sh}`.

## Conventions and patterns (QML)

- `property var main: Services.MainService` (as in `shell.qml`).
- IO: `Quickshell.Io` (`Process`, `File`, `SplitParser`, `StdioCollector`).
- Services: `Quickshell.Services.{UPower,Pipewire}`.

## Workflows

- Stow to $HOME from repo root (adapt set):
  - `stow -t ~ quickshell hypr niri waybar fish ghostty swaync swayosd swayidle swaylock alacritty kitty mpv`
- Run Quickshell manually for testing:
  - `quickshell` and watch for `=== MainService System Info ===` logs.

## Examples in this repo

- `MainService.qml` – detects session (Hyprland/Niri), Arch-based distro, UPower/Pipewire devices, monitor count (xrandr); emits `detectionFinished` used by `shell.qml` for logging.
- `niri/config.kdl` – spawns `quickshell`, `swayidle`, `swayosd-server`, `swaync`, etc.; pins workspaces to outputs.

## Gotchas

- Ensure tools used by scripts exist: `hyprctl`, `jq`, `gpu-screen-recorder`, `nmcli`, `xrandr`, `notify-send`.

If you have questions or want a recipe for a specific pattern, ask and these notes will be extended.
