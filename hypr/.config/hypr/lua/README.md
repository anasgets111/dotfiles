# Hyprland Lua Migration

This directory is a staged Lua version of the active Hyprland config.

The current `../hyprland.conf` setup remains active until this tree is moved
or referenced explicitly as the Hyprland config. Hyprland currently loads
`hyprland.lua` instead of `hyprland.conf` when a Lua config is present at the
active config path.

Monitor selection is handled in Lua by `config/monitors.lua`:

- `Wolverine` uses the desktop monitor profile.
- `Mentalist` uses the laptop monitor profile.
- Unknown hostnames fall back to the laptop profile.

`hyprlock.conf` and `hypridle.conf` are intentionally not converted. The
Hyprland Lua migration applies to the compositor config; other Hypr tools still
use their existing config language for now.
