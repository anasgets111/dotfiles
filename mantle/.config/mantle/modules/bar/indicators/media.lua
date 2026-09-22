-- The bars are flat because cava needs 30fps frames and the engine has no shader or canvas node:
-- pushing `rect` levels per frame trips the 5ms CPU budget. A spectrum at zero draws this same row.
local theme = require("config.theme")

-- Cava is configured for 256, but each bar here is a real node and at rest they read as one rule.
local BARS = 48

local GAP = theme.border_width
local BAR_HEIGHT = theme.border_width_medium

local tint = mantle.mpris:map(function(m)
    for _, player in ipairs((m and m.players) or {}) do
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
        height = BAR_HEIGHT,
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
        spacing = GAP,
        animate = { background = { duration = theme.animation_ms, easing = "OutCubic" } },
        children = children,
    } },
}
