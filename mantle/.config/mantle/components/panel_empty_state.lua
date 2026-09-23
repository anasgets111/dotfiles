-- Empty-list state; a bare dim `cell` reads as a load failure. With `opts.icon`, a large dim glyph
-- over the message at `panel_empty_height`, which reads as state rather than a gap; without it, one line.
local theme = require("config.theme")
local cell = require("components.cell")
local glyph = require("components.glyph")
local util = require("lib.util")

---@param message string|Bound
---@param visible boolean|Bound
---@param opts? { icon?: string|Bound|table, subtext?: string|Bound }
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
    local subtext = opts.subtext
    if subtext then
        -- Says whether nothing arrived or something suppresses the list. A colour at that alpha,
        -- since `cell` takes no node `opacity`.
        lines[#lines + 1] = cell(subtext, theme.with_opacity(theme.DIM, theme.opacity.muted), theme.font.sm, {
            align = "Center",
            width = "Fill",
            wrap = "Word",
            visible = type(subtext) ~= "userdata" or util.shown_when(subtext, function(value)
                return value ~= ""
            end),
        })
    end
    return column {
        width = "Fill",
        height = opts.icon and theme.panel_empty_height or theme.control.lg,
        align_v = "Center",
        spacing = theme.spacing.sm,
        visible = visible,
        children = lines,
    }
end
