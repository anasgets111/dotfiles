-- Left click opens the picker. Right click deals every screen a new file from the folder.
local icons = require("config.icons")
local icon_button = require("components.icon_button")
local ui_state = require("lib.ui_state")
local wallpaper = require("lib.wallpaper")
local tooltip = require("components.tooltip")

local SLOT = "wallpaper"

local wallpaper_button = icon_button(icons.wallpaper, nil, {
    slot = SLOT,
    selected = ui_state.modal_showing("wallpaper_picker"),
    on_buttons = {
        left = function() ui_state.toggle_modal("wallpaper_picker") end,
        right = wallpaper.randomize_all,
    },
})

local wallpaper_tooltip = tooltip({
    slot = SLOT, text = "Open wallpaper picker / right-click randomize",
})

return { indicator = wallpaper_button, tooltips = { wallpaper_tooltip } }
