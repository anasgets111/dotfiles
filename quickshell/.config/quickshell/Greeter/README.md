# Obelisk Greeter

Standalone greetd greeter for Wayland compositors (Niri/Hyprland). Uses [Quickshell](https://quickshell.outfoxxed.me/) with the `Quickshell.Services.Greetd` API.

> **Requires `quickshell-git`** (not stable quickshell).

## Quick Setup

```bash
# From the dotfiles root:
./quickshell/scripts/setup-greetd.sh
```

The setup script will:

1. Install `greetd` if missing
2. Create a `greeter` system user
3. Copy this entire folder to `/etc/xdg/quickshell/obelisk-greeter/`
4. Configure and enable `greetd.service`

## Manual Setup

```bash
# Install greetd
sudo pacman -S greetd

# Create greeter user
sudo useradd -r -g greeter -d /var/lib/greeter -s /bin/bash -c "System Greeter" greeter

# Copy this folder
sudo cp -r . /etc/xdg/quickshell/obelisk-greeter/
sudo chmod +x /etc/xdg/quickshell/obelisk-greeter/dots-greeter

# Create cache dir
sudo mkdir -p /var/cache/obelisk-greeter
sudo chown greeter:greeter /var/cache/obelisk-greeter

# Configure greetd (/etc/greetd/config.toml):
# [terminal]
# vt = 1
# [default_session]
# user = "greeter"
# command = "/etc/xdg/quickshell/obelisk-greeter/dots-greeter --detect"

# Enable
sudo systemctl enable greetd
```

## Files

| File                 | Description                                        |
| -------------------- | -------------------------------------------------- |
| `shell.qml`          | Entry point — theme, state, memory, surface        |
| `GreeterContent.qml` | Login UI — clock, avatar, input, session picker    |
| `dots-greeter`       | Compositor launcher — auto-detects niri/hyprland   |

## Testing

```bash
# Render test (shows as overlay, Ctrl+C to kill):
qs -p /path/to/this/folder

# Full test:
sudo greetd
```
