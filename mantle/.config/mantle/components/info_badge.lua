-- A short bold count on a filled capsule with the shell's hairline, sized by its text rather than
-- a fixed width.
--
-- Extraction rule: `modules/bar/panels/bluetooth_panel.lua` and
-- `modules/bar/panels/notification_history.lua` use the same capsule. Two agreeing call sites make
-- a component.
--
-- The text takes `text_contrast(ground)`, not `FG`: these grounds are filled swatches -- accent,
-- peach, red -- and white on peach is unreadable.
local theme = require("config.theme")
local cell = require("components.cell")
local util = require("lib.util")

---@param label string|Bound
---@param ground? Color|Bound The capsule's fill. Default `theme.GLASS_CONTROL`.
---@param opts? { visible?: boolean|Bound, align_v?: "Start"|"Center"|"End", opacity?: number }
return function(label, ground, opts)
    opts = opts or {}
    ground = ground or theme.GLASS_CONTROL
    -- A live ground maps contrast over itself, as `components/icon_button.lua` does. The recorder's
    -- elapsed badge swaps peach for red under capture; ink must follow or one state is unreadable.
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
