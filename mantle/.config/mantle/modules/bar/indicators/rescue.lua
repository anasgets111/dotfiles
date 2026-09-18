-- First on the bar so a config error cannot be pushed off its edge; it occupies no width unless
-- configuration failed, and matches its glyph neighbours so a failed bar keeps its shape.
--
-- Hover names the failure; click opens the whole log in `modules/global/rescue_details.lua`.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local error_log = require("lib.rescue")

local SLOT = "rescue"

local indicator = icon_button(icons.warning, function()
    ui_state.toggle_modal("rescue")
end, {
    slot = SLOT,
    background = theme.RED,
    background_hover = theme.RED_HOVER,
    selected = ui_state.modal_showing("rescue"),
    visible = error_log:map(function(text)
        return text ~= ""
    end),
})

local rescue_tooltip = tooltip({
    id = "rescue_tooltip",
    slot = SLOT,
    children = {
        -- mlua puts the message first and the traceback under it.
        cell(error_log:map(function(text)
            return util.truncate(text:match("^[^\n]*"), 90)
        end), theme.FG, theme.font.sm),
        cell("Click for the full error", theme.DIM, theme.font.xs),
    },
})

return { indicator = indicator, tooltip = rescue_tooltip }
