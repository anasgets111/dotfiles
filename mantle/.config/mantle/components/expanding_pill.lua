-- Collapsed shows one circle and hover shows all. Collapsing waits out `collapse_ms`, so a returning
-- pointer cancels it, and `hold_open` keeps it open for a countdown. A changed collapsed slot hands
-- off in place with no offset arithmetic.
--
-- The row's `spacing` eases to zero on collapse, since it would still gap a zero-width cell.
local theme = require("config.theme")
local util = require("lib.util")

local pill = {}

---@class ExpandingPillOpts
---@field slot string The hover slot the whole row declares.
---@field collapse_ms? integer How long after the pointer leaves the pill stays open. Default `theme.animation_ms`.
---@field hold_open? Signal<boolean> Keeps the pill open while true.
---@field count integer|Signal<integer> How many cells it holds, for the width it heads to.

---@param opts ExpandingPillOpts
function pill.new(opts)
    local hovered = hover(opts.slot)
    local lingering = util.linger(hovered, opts.collapse_ms or theme.animation_ms)
    local expanded = opts.hold_open
        and computed({ lingering, opts.hold_open }, function(open, held)
            return open or held
        end)
        or lingering
    -- Between cells; a `list` of cells takes it as its own `spacing`, with `animate`.
    local spacing = expanded:map(function(open)
        return open and theme.spacing.sm or 0
    end)
    local function heading(open, cells)
        return open and cells * theme.item_width + math.max(0, cells - 1) * theme.spacing.sm or theme.item_width
    end
    local self = {
        expanded = expanded,
        spacing = spacing,
        animate = { spacing = theme.animation_ms },
        geometry = geometry(opts.slot),
        --- Where the pill is heading: `center_side.lua` makes room before the ease reaches it.
        width = type(opts.count) == "number" and expanded:map(function(open)
            return heading(open, opts.count)
        end) or computed({ expanded, opts.count }, heading),
    }

    --- One cell. `circle` fills it, so a cell narrowing to zero narrows its circle too.
    --- `shown` marks the circle the collapsed pill keeps.
    ---@param circle table
    ---@param shown Signal<boolean>
    function self.cell(circle, shown)
        circle.width = "Fill"
        circle.height = "Fill"
        return row {
            width = computed({ expanded, shown }, function(open, kept)
                return (open or kept) and theme.item_width or 0
            end),
            height = theme.item_height,
            align_v = "Center",
            opacity = computed({ expanded, shown }, function(open, kept)
                return (open or kept) and 1 or 0
            end),
            animate = { width = theme.animation_ms, opacity = theme.animation_ms },
            children = { circle },
        }
    end

    --- The pill, the hover region for every cell and the gaps between them.
    ---@param children table Cells, or a `list` of them.
    function self.row(children)
        return row {
            height = theme.item_height,
            align_v = "Center",
            geometry = self.geometry,
            hover = hovered,
            spacing = spacing,
            animate = self.animate,
            children = children,
        }
    end

    return self
end

return pill
