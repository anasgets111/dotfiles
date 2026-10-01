-- A bold label on a capsule, or a circle when given a diameter. The ink is `text_contrast(ground)`, not
-- `FG`, because these grounds are filled swatches and white on peach is unreadable.
local theme = require("config.theme")
local cell = require("components.cell")
local util = require("lib.util")

---@param label string|Bound
---@param ground? Color|Bound The capsule's fill. Default `theme.GLASS_CONTROL`.
---@param opts? { visible?: boolean|Bound, opacity?: number, diameter?: number }
return function(label, ground, opts)
    opts = opts or {}
    ground = ground or theme.GLASS_CONTROL
    -- A live ground maps contrast over itself: the recorder's badge swaps peach for red mid-capture.
    local ink = util.lift(ground, theme.text_contrast)
    local diameter = opts.diameter or theme.control.xs
    return row {
        width = opts.diameter,
        height = diameter,
        align_h = opts.diameter and "Center" or nil,
        align_v = "Center",
        visible = opts.visible,
        opacity = opts.opacity,
        padding = opts.diameter and 0 or { left = theme.spacing.sm, right = theme.spacing.sm },
        radius = diameter / 2,
        background = ground,
        border_width = theme.border_width,
        border_color = theme.GLASS_BORDER,
        children = { cell(util.bold(label), ink, theme.font.xs, {
            align = "Center",
            align_v = "Center",
        }) },
    }
end
