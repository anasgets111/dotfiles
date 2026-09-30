-- Empty-list state, since a bare dim `cell` reads as a load failure. `opts.icon` adds a large dim glyph
-- over the message at `panel_empty_height`. Without it the state is one line.
local theme = require("config.theme")
local cell = require("components.cell")
local glyph = require("components.glyph")

---@param message string|Bound
---@param visible boolean|Bound
---@param opts? { icon?: string|Bound|table }
return function(message, visible, opts)
    opts = opts or {}
    local lines = {}
    local mark = opts.icon
    if type(mark) == "table" then
        lines[#lines + 1] = mark
    elseif mark then
        lines[#lines + 1] = glyph(mark, theme.DIM, theme.icon.xl, { align = "Center" })
    end
    lines[#lines + 1] = cell(message, theme.DIM, theme.font.sm, { align = "Center" })
    return column {
        width = "Fill",
        height = opts.icon and theme.panel_empty_height or theme.control.lg,
        align_v = "Center",
        spacing = theme.spacing.sm,
        visible = visible,
        children = lines,
    }
end
