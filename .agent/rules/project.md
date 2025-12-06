---
description: Obelisk Shell - Project Architecture & Stow Packages
globs: ["**/*"]
alwaysApply: true
---

# Obelisk Shell - Project Overview

Modular Wayland desktop environment built on **Quickshell** (QML-based shell framework), supporting both **Hyprland** and **Niri** compositors. All configurations are managed via **GNU Stow** for symlink-based deployment.

## Technology Stack

- **Shell Framework**: Quickshell (Qt/QML-based)
- **Compositors**: Hyprland, Niri
- **Config Management**: GNU Stow
- **Primary Shell**: Fish

## Stow Package Structure

Each top-level directory is a **Stow package** that symlinks into `$HOME`:

- **Core packages**: `quickshell`, `hypr`, `niri`, `fish`, `kitty`, `nvim`, `home`, `config`
- **Optional packages**: `swaylock`, `swaync`, `swayosd`, `waybar` (deprecated, kept for fallback)

Deploy: `stow -t ~ <package>...` | Remove: `stow -D -t ~ <package>`

## System Detection

`MainService` singleton provides:

- `currentWM`: "hyprland" | "niri" | "other"
- `isLaptop`, `isArchBased`, `hasBrightnessControl`, `hasKeyboardBacklight`

Check compositor before using WM-specific features:

```qml
if (MainService.currentWM === "hyprland") {
    // Hyprland-specific IPC
} else if (MainService.currentWM === "niri") {
    // Niri-specific commands
}
```

## AI Agent Workflow

- **Always check documentation**: Use project docs or `codebase_search` tool for library references
- **Use sequential thinking**: Apply `mcp_sequentialthinking` tool for complex logic and decision-making
- **Leverage memory**: Store and recall important patterns and decisions using conversation context and artifacts
