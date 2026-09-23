local icons = require("config.icons")
local theme = require("config.theme")
local glyph = require("components.glyph")

local TURN = { rotate = { duration = 1000, easing = "Linear", keyframes = { 0, 360 }, loops = "Infinite" } }

-- `animate` follows `visible`, so a hidden spinner stops asking for a frame every frame.
---@param visible Signal
---@param size integer
---@param color? Color|Bound
return function(visible, size, color)
    return glyph(icons.refresh, color or theme.DIM, size, {
        align = "Center",
        align_v = "Center",
        visible = visible,
        animate = visible:map(function(on)
            return on and TURN or {}
        end),
    })
end
