-- The bars are flat because cava needs 30fps frames and the engine has no shader or canvas node:
-- pushing `rect` levels per frame trips the 5ms CPU budget. A spectrum at zero draws this same row.
local theme = require("config.theme")

-- Cava is configured for 256, but each bar here is a real node and at rest they read as one rule.
local BARS = 48

local tint = mantle.mpris:map(function(mpris)
    for _, player in ipairs((mpris and mpris.players) or {}) do
        if player.play_state == "Playing" then
            return theme.ACCENT_MEDIUM
        end
    end
    return theme.ACCENT_SUBTLE
end)

local children = {}
for index = 1, BARS do
    children[index] = rect {
        width = "Fill",
        height = theme.border_width_medium,
        align_v = "End",
        background = tint,
    }
end

return rect {
    width = theme.center_zone_width,
    height = "Fill",
    children = { row {
        width = "Fill",
        height = "Fill",
        align_v = "End",
        padding = theme.spacing.xs,
        spacing = theme.border_width,
        children = children,
    } },
}
