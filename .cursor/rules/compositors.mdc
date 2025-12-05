---
description: Hyprland and Niri compositor configuration
globs: ["hypr/**/*", "niri/**/*"]
alwaysApply: false
---

# Compositor Integration

## Hyprland

- **Main config**: `hypr/.config/hypr/hyprland.conf` (sources modular configs from `config/`)
- **Monitor detection**: `config/detect-monitors.sh` symlinks `monitors.conf` based on hostname
  - `Wolverine` → `desktop.conf`
  - `Mentalist` → `laptop.conf`
- **Startup**: `config/startup.conf` launches Quickshell + services

## Niri

- **Config**: `niri/.config/niri/config.kdl`
- **Workspaces**: Pre-defined with output assignments (e.g., `workspace "Code" {open-on-output "DP-3"}`)
- **Startup**: Quickshell launched via `spawn-at-startup "quickshell"`

## Both Compositors

1. Set cursor theme (Bibata-Modern-Ice)
2. Launch Quickshell (replaces waybar/swaync/swayosd)
3. Start clipboard manager (`cliphist`)
4. Autostart apps on specific workspaces

## WM-Agnostic Code

Always check compositor before using WM-specific features:

```qml
if (MainService.currentWM === "hyprland") {
    // Hyprland-specific IPC
} else if (MainService.currentWM === "niri") {
    // Niri-specific commands
}
```

## Wallpaper Management

`WallpaperService` handles per-monitor wallpapers:

- `wallpaperFor(screenName)` returns `{wallpaper: path, mode: "fill"|"fit"|...}`
- AnimatedWallpaper component instantiated per monitor via `Variants`
