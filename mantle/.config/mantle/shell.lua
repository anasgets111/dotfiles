-- Development bar, real-session fixture, and worked example. If they conflict, the fixture wins.
-- `just run` builds both binaries and starts `target/debug/mantle` on this directory.
-- The Supervisor finds `mantle-renderer` beside its own binary (`renderer_binary_path` in
-- `supervisor/src/generation.rs`), not through Cargo; `cargo run -p supervisor` can rebuild one half
-- and launch a stale Renderer. A Renderer older than `fonts` then reports `attempt to call a nil
-- value (global 'fonts')` at this file.
--
-- Editing reloads in place on the same Lua VM. Changing a surface's `id`/`layer`/`anchor`/
-- `monitor`/`namespace` rebuilds that surface; other edits update it live.

-- `config/` holds tokens, `components/` dumb reusable widgets, `lib/` node-free functions, and
-- `modules/` assembles `bar/indicators/`, `bar/panels/`, `global/`, `notification/`, `osd/`, and
-- `shell/`'s panel host. There is no `services/`: Supervisor-owned capabilities push signals on
-- `mantle`; the config reads `mantle.audio`, and the data layer is not this config's job.
--
-- `require` resolves only inside this directory and its cache clears before each re-evaluation,
-- so any file below can reload the bar in place.

-- Bind modules before the return. Lua 5.4 `require` returns the module and loader data, unlike 5.3;
-- a final `require` in a table expands both, adds a path such as "/path/to/lock.lua", and produces
-- `error converting Lua string to table`, with no clue which entry is wrong. Bind it as
-- `local x = require(...)` to keep only the module.
-- Declare the font chain before text measurement. `femtovg` and `cosmic-text` fall back per glyph,
-- so body text and Nerd Font private-use glyphs choose their faces independently; without it, the
-- engine resolves `sans-serif` and the glyphs become tofu.
--
-- Read once at startup. Editing the list changes nothing until restart; see
-- `renderer/src/lua/fonts.rs`.
fonts {
    "CaskaydiaCove Nerd Font Propo",
    "Noto Sans",
    "Noto Sans CJK JP",
    "Noto Color Emoji",
}

local wallpaper = require("modules.global.wallpaper")
local notifications = require("modules.notification.popup")
local osd = require("modules.osd.popup")
local bar = require("modules.bar")
local settings = require("modules.bar.panels.settings")
local panel_host = require("modules.shell.panel_host")
local modal_host = require("modules.global.modal_host")
local lock_screen = require("modules.global.lock")
local polkit_dialog = require("modules.global.polkit")
local bluetooth_pairing = require("modules.global.bluetooth_pairing")
-- Not a surface. Registers the battery's OSD, low-battery notification and suspend effects once;
-- it returns nothing to the surface list.
require("modules.global.power_events")
-- Not a surface. Registers the idle clock: one `register_threshold`, one `mantle.system` handler,
-- and the three actions for an unattended seat. `lib/idle.lua` owns the actions; the bar reads the
-- same facts without requiring this module.
require("modules.global.idle")

local surfaces = {
    wallpaper.desktop,
    wallpaper.overview,
    notifications,
    osd,
    settings,
    panel_host,
}
table.move(bar.tooltips, 1, #bar.tooltips, #surfaces + 1, surfaces)
surfaces[#surfaces + 1] = modal_host
surfaces[#surfaces + 1] = lock_screen
surfaces[#surfaces + 1] = polkit_dialog
surfaces[#surfaces + 1] = bluetooth_pairing

return surfaces
