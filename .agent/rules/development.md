---
description: Development workflows and testing
globs: ["**/*"]
alwaysApply: false
---

# Development Workflows

## Testing Quickshell

```bash
quickshell  # Run in foreground (check logs for "=== MainService System Info ===")
```

**No compilation needed** - Quickshell directly interprets QML files. Just save and restart.

## System Updates

Use `bin/.local/bin/update.sh`:

- `--quiet`: Minimal output
- `--stream`: Live verbose output
- `--polkit`: Use pkexec for system packages, paru for AUR

## Fish Shell

Primary shell (`fish/.config/fish/config.fish`):

- History per terminal context (ZED_TERM → zed, VSCODE_INJECTION → vscode, etc.)

## Stow Deployment

Deploy packages:

```bash
stow -t ~ quickshell hypr niri fish kitty nvim home config
```

Remove packages:

```bash
stow -D -t ~ <package>
```

## Codebase Exploration

- ALWAYS read and understand relevant files before proposing code edits
- Do not speculate about code you have not inspected
- If the user references a specific file/path, you MUST open and inspect it before explaining or proposing fixes
- Be rigorous and persistent in searching code for key facts
- Thoroughly review the style, conventions, and abstractions of the codebase before implementing new features
