local theme = require("config.theme")
local left = require("modules.bar.left_side")
local center = require("modules.bar.center_side")
local right = require("modules.bar.right_side")
local power_menu = require("modules.bar.panels.power_menu")
local battery = require("modules.bar.indicators.battery")
local date_time = require("modules.bar.indicators.date_time")
local launcher = require("modules.bar.indicators.launcher_button")
local wallpaper = require("modules.bar.indicators.wallpaper_button")
local network = require("modules.bar.indicators.network")
local bluetooth = require("modules.bar.indicators.bluetooth")
local screen_recorder = require("modules.bar.indicators.screen_recorder")
local idle_inhibitor = require("modules.bar.indicators.idle_inhibitor")
local updates = require("modules.bar.indicators.updates")
local rescue = require("modules.bar.indicators.rescue")
local keyboard_layout = require("modules.bar.indicators.keyboard_layout")
local privacy = require("modules.bar.indicators.privacy")
local special_workspaces = require("modules.bar.indicators.special_workspaces")
local sys_tray = require("modules.bar.indicators.sys_tray")
local audio_panel = require("modules.bar.panels.audio_panel")

local indicator = row {
    width = "Fill",
    height = theme.bar_height,
    background = theme.GLASS_SURFACE,
    blur = true,
    padding = { left = theme.spacing.md, right = theme.spacing.md },
    children = { left, center, right },
}

local tooltips = {
    battery.tooltip,
    date_time.tooltip,
    launcher.tooltip,
    wallpaper.tooltip,
    network.tooltip,
    bluetooth.tooltip,
    screen_recorder.tooltip,
    idle_inhibitor.tooltip,
    updates.tooltip,
    rescue.tooltip,
    keyboard_layout.tooltip,
    privacy.camera_tooltip,
    privacy.microphone_tooltip,
    privacy.screenshare_tooltip,
    special_workspaces.tooltip,
    sys_tray.tooltip,
    audio_panel.output_tooltip,
    audio_panel.input_tooltip,
}
table.move(power_menu.tooltips, 1, #power_menu.tooltips, #tooltips + 1, tooltips)

return { indicator = indicator, tooltips = tooltips }
