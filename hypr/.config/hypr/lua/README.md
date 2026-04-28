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

The Lua monitor detection intentionally keeps a few defensive fallbacks because
Hyprland's embedded Lua runtime is new and not locally verifiable on Hyprland
0.54.x. Things to check when moving to a Lua-capable Hyprland release:

- Whether `debug.getinfo()` is available for resolving the config directory.
- Whether `os.getenv("HOSTNAME")` is populated in the Hyprland session.
- Whether `io.popen("uname -n")` is allowed; embedded Lua runtimes sometimes
  restrict process spawning.
- Whether `package.path` module loading behaves the same when this tree is
  moved or referenced from the active `~/.config/hypr` config path.

Once Hyprland `git` or `0.55+` is installed, validate this staged config with:

```bash
Hyprland --verify-config --config ~/.config/hypr/lua/hyprland.lua
```

On Hyprland `0.54.x`, this command is expected to fail because the binary still
parses `.lua` files as legacy hyprlang.

`hyprlock.conf` and `hypridle.conf` are intentionally not converted. The
Hyprland Lua migration applies to the compositor config; other Hypr tools still
use their existing config language for now.
