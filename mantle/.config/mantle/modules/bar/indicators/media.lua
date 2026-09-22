-- ## Why the bars are flat
--
-- Cava needs 30fps frames. The engine has no shader or canvas node; its nine node types draw no
-- waveform.
-- `rect`s can carry levels, but per-frame pushes are the first such path here; the bar logs
-- `exceeded the 5ms CPU budget` failures. Not attempted.
--
-- Flat is not a placeholder shape, though: a spectrum at zero level draws exactly this row.
local theme = require("config.theme")

-- Cava's configured bar count is 256. Fewer here because each is a real node, not a shader lane.
-- At rest it reads as the same fine rule; 256 static children buy nothing until they carry levels.
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
        padding = { top = theme.spacing.xs, right = theme.spacing.xs, bottom = theme.spacing.xs, left = theme.spacing.xs },
        spacing = GAP,
        animate = { background = { duration = theme.animation_ms, easing = "OutCubic" } },
        children = children,
    } },
}
