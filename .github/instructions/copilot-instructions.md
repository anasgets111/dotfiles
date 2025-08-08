---
applyTo: "**"
---

# Copilot Instructions for Dotfiles & Quickshell Workspace

## Overview

This repository manages a modular Linux desktop environment using quickshell (QML), Hyprland, Niri, and Fish shell, with extensive system integration and custom scripts. It is designed for rapid switching between desktop, laptop, and docked setups.

## Key Components

- **quickshell/**: QML-based UI shell. Entry: `shell.qml`. Bar widgets in `modules/Bar/` (e.g., `Bar.qml`, `PowerMenu.qml`, `BatteryIndicator.qml`).
- **hypr/config/**: Hyprland configs. Monitor layouts: `desktop.conf`, `laptop.conf`, `monitors.conf`. Dynamic selection via `detect-monitors.sh`.
- **niri/**: Niri compositor config in `niri/config.kdl`. Used as an alternative to Hyprland.
- **fish/**: Shell config, aliases, and package helpers (`conf.d/packages.fish`).
- **nu/**: Nushell config and scripts.
- **bin/**: System scripts (e.g., `update.sh`, `RecordingStatus.sh`).

## Developer Workflows

- **Startup**: Hyprland loads `startup.conf` (launches quickshell, swayosd, etc). Niri uses `niri/config.kdl` if selected as compositor.
- **Monitor Config**: Run `detect-monitors.sh` to auto-link the correct monitor config based on host and connected displays. Do not edit `monitors.conf` directly.
- **System Updates**: Use `bin/update.sh` (also triggered from quickshell bar via `ArchChecker.qml`).
- **Fish Shell**: Use aliases/functions for package management. See `conf.d/packages.fish` for `native`, `aur`, `chaotic`, `version`.

## Project-Specific Patterns

- **QML**: Each bar widget is a QML file in `modules/Bar/`. Use `Theme.qml` for styling, `DetectEnv.qml` for environment/distro detection.
- **Process Integration**: QML modules interact with shell/system via `Process` and `Quickshell.execDetached`.
- **Notifications**: Use `notify-send` from QML and shell scripts.
- **Dynamic UI**: Bar adapts to environment (e.g., `ArchChecker` for Arch, `BatteryIndicator` for laptops).
- **Compositor Choice**: Both Hyprland and Niri are supported. Switch by changing the session and relevant configs.

## Conventions

- **QML**: PascalCase for types, camelCase for properties/ids. Use singletons for shared state (`Theme.qml`, `DetectEnv.qml`).
- **Shell**: Scripts use `bash` or `fish`, with strict error handling (`set -euo pipefail`).
- **Packages**: List of required packages in `hypr/config/packages` (includes Hyprland, Niri, quickshell, and related tools).

## Integration Points

- **Pipewire**: QML modules can import `Quickshell.Services.Pipewire` for audio.
- **UPower**: Battery status via `Quickshell.Services.UPower`.
- **Wayland**: Uses `Quickshell.Wayland` for screen/window management.
- **Niri**: Configured in `niri/config.kdl` for alternative Wayland session.

## Examples

- Add a bar widget: create QML in `modules/Bar/`, import in `Bar.qml`.
- Add a system alias: edit `fish/config.fish` or `conf.d/various.fish`.
- Change monitor layouts: edit `desktop.conf`/`laptop.conf`, run `detect-monitors.sh`.
- Switch compositor: update session to use Hyprland or Niri, and edit respective configs.

## AI Agent Workflow for Tool Usage

To maximize productivity and accuracy, follow this workflow when making changes or answering questions:

1. **Check the File/Context**: Start by reading the relevant file(s) and gathering workspace context. Use file search, grep, or semantic search as needed.
2. **Use Sequential Thinking**: Break down the problem using step-by-step reasoning. Formulate hypotheses, question assumptions, and revise your plan as you learn more.
3. **Fetch Documentation**: When you need details about a library, tool, or API, use the Context7 documentation tools to fetch up-to-date docs before proceeding.
4. **Ask for User Input**: If requirements are unclear or multiple approaches are possible, ask the user for clarification or preferences before making major changes.
5. **Form a Plan**: Use your thinking tools to outline a plan of action. Summarize your approach for the user if the task is complex.
6. **Make Changes**: Edit files, run scripts, or update configs as needed. Use project conventions and reference examples from the codebase.
7. **Validate and Iterate**: Check for errors, test the workflow, and ask the user for feedback. Iterate as needed to ensure the solution fits the user's intent.

This workflow ensures that changes are well-informed, context-aware, and aligned with user expectations.
