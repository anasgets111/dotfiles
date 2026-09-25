local theme = require("config.theme")
local rescue_module = require("modules.bar.indicators.rescue")
local power_menu = require("modules.bar.indicators.power_menu")
local updates_module = require("modules.bar.indicators.updates")
local idle_inhibitor = require("modules.bar.indicators.idle_inhibitor")
local keyboard_module = require("modules.bar.indicators.keyboard_layout")
local battery = require("modules.bar.indicators.battery")
local launcher = require("modules.bar.indicators.launcher_button")
local wallpaper_button = require("modules.bar.indicators.wallpaper_button")
local special_workspaces = require("modules.bar.indicators.special_workspaces")
local workspaces_module = require("modules.bar.indicators.workspace_strip")

-- `width = "Fill"`: this and `right_side.lua` split the centre's remainder evenly. Each inner row is
-- content-sized, so `center_side.lua` measures where the indicators end.
return row {
    width = "Fill",
    height = "Fill",
    align_h = "Start",
    align_v = "Center",
    children = { row {
        geometry = geometry("bar-left"),
        height = "Fill",
        align_v = "Center",
        spacing = theme.spacing.sm,
        children = {
            rescue_module.indicator,
            power_menu.button,
            updates_module.indicator,
            idle_inhibitor.indicator,
            keyboard_module.indicator,
            battery.indicator,
            launcher.button,
            wallpaper_button.button,
            special_workspaces.indicator,
            workspaces_module,
        },
    } },
}
