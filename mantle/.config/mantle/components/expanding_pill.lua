-- Collapsed shows one circle and hover shows all. Collapsing waits out `collapse_ms`, so a returning
-- pointer cancels it, and `hold_open` keeps it open for a countdown. A changed collapsed slot hands
-- off in place with no offset arithmetic.
--
-- Each cell owns its right padding, because row `spacing` would still gap a zero-width cell. The
-- expanded pill trails one `spacing.sm` that nothing sits close enough to show.
local theme = require("config.theme")
local util = require("lib.util")

local pill = {}

---@class ExpandingPillOpts
---@field slot string The hover slot the whole row declares.
---@field collapse_ms? integer How long after the pointer leaves the pill stays open. Default `theme.animation_ms`.
---@field hold_open? Signal<boolean> Keeps the pill open while true.

---@param opts ExpandingPillOpts
function pill.new(opts)
    local hovered = hover(opts.slot)
    local lingering = util.linger(hovered, opts.collapse_ms or theme.animation_ms)
    local expanded = opts.hold_open
        and computed({ lingering, opts.hold_open }, function(open, held)
            return open or held
        end)
        or lingering
    local self = { expanded = expanded }

    --- One cell. `circle` fills it, so a cell narrowing to zero narrows its circle too.
    --- `shown` marks the circle the collapsed pill keeps.
    ---@param circle table
    ---@param shown Signal<boolean>
    function self.cell(circle, shown)
        circle.width = "Fill"
        circle.height = "Fill"
        return row {
            width = computed({ expanded, shown }, function(open, kept)
                if open then
                    return theme.item_width + theme.spacing.sm
                end
                return kept and theme.item_width or 0
            end),
            height = theme.item_height,
            align_v = "Center",
            padding = expanded:map(function(open)
                return { right = open and theme.spacing.sm or 0 }
            end),
            opacity = computed({ expanded, shown }, function(open, kept)
                return (open or kept) and 1 or 0
            end),
            animate = { width = theme.animation_ms, padding = theme.animation_ms, opacity = theme.animation_ms },
            children = { circle },
        }
    end

    --- The pill, the hover region for every cell and the gaps between them.
    ---@param children table Cells, or a `list` of them.
    function self.row(children)
        return row {
            height = theme.item_height,
            align_v = "Center",
            hover = hovered,
            children = children,
        }
    end

    return self
end

return pill
