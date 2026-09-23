-- The surface list. `config/` holds tokens, `components/` reusable widgets, `lib/` node-free
-- functions, and `modules/` assembles them. Capabilities push their own signals on `mantle`, so
-- there is no data layer here.
--
-- Editing reloads in place. Changing a surface's `id`/`layer`/`anchor`/`monitor`/`namespace`
-- rebuilds that surface; other edits update it live.
--
-- Bind every `require` to a local: in a table it expands its second return value and fails with
-- `error converting Lua string to table`.

-- The font chain has to precede text measurement, and is read once at startup: editing it changes
-- nothing until a restart. Without it the engine resolves `sans-serif` and Nerd Font glyphs go tofu.
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
local idle_settings = require("modules.global.idle_settings")
local lock_screen = require("modules.global.lock")
local polkit_dialog = require("modules.global.polkit")
local bluetooth_pairing = require("modules.global.bluetooth_pairing")
-- Not surfaces: these register the battery effects and the idle clock's actions, and return nothing.
require("modules.global.power_events")
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
table.move(idle_settings.popups, 1, #idle_settings.popups, #surfaces + 1, surfaces)
table.move({ modal_host, lock_screen, polkit_dialog, bluetooth_pairing }, 1, 4, #surfaces + 1, surfaces)

return surfaces
