-- A hairline rule. `GLASS_BORDER`, since every surface here is glass: `BORDER` is surface2 and
-- vanishes between its greys, and `BORDER_SUBTLE` is too faint for 1px.
local theme = require("config.theme")

---@param opts? { margin?: table }
return function(opts)
    opts = opts or {}
    return rect {
        width = "Fill",
        height = theme.border_width,
        align_v = "Center",
        margin = opts.margin,
        background = theme.GLASS_BORDER,
    }
end
