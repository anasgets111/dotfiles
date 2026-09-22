-- A short bold count on a filled capsule, sized by its text. The ink is `text_contrast(ground)`, not
-- `FG`: these grounds are filled swatches, and white on peach is unreadable.
local theme = require("config.theme")
local cell = require("components.cell")
local util = require("lib.util")

---@param label string|Bound
---@param ground? Color|Bound The capsule's fill. Default `theme.GLASS_CONTROL`.
---@param opts? { visible?: boolean|Bound, align_v?: "Start"|"Center"|"End", opacity?: number }
return function(label, ground, opts)
    opts = opts or {}
    ground = ground or theme.GLASS_CONTROL
    -- A live ground maps contrast over itself: the recorder's badge swaps peach for red mid-capture.
    ---@type Color|Signal
    local ink
    if type(ground) == "userdata" then
        ---@cast ground Signal
        ink = ground:map(theme.text_contrast)
    else
        ---@cast ground Color
        ink = theme.text_contrast(ground)
    end
    local content = util.bold(label)
    return row {
        height = theme.control.xs,
        align_v = opts.align_v or "Center",
        visible = opts.visible,
        opacity = opts.opacity,
        padding = { left = theme.spacing.sm, right = theme.spacing.sm },
        radius = theme.control.xs / 2,
        background = ground,
        border_width = theme.border_width,
        border_color = theme.GLASS_BORDER,
        children = { cell(content, ink, theme.font.xs, {
            align = "Center",
            align_v = "Center",
        }) },
    }
end
