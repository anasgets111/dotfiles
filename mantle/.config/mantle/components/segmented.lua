-- A radio drawn as one control: an outlined bar whose segments are the options, the chosen one
-- filled. Eight loose tiles read as eight buttons; one bar reads as one setting with eight positions.
-- The bar's rounded clip cuts the end segments, so segments themselves are square.
local theme = require("config.theme")
local cell = require("components.cell")
local util = require("lib.util")

---@class SegmentedOpts
---@field slot string A `hover` prefix unique to this control; each segment appends its value.
---@field options any[]|Signal The values, in bar order.
---@field value Signal The chosen value.
---@field format? fun(value: any): string Default `tostring`.
---@field on_select fun(value: any)
---@field width? Length
---@field height? integer Default `theme.control.md`.
---@field visible? boolean|Bound

---@param opts SegmentedOpts
return function(opts)
    local format = opts.format or tostring
    local function segment(value)
        local hovered = hover(opts.slot .. "-" .. tostring(value))
        local chosen = opts.value:map(function(current)
            return current == value
        end)
        local tint = util.tint(chosen, hovered)
        return button {
            width = "Fill",
            height = "Fill",
            hover = hovered,
            background = tint(theme.ACCENT_LIGHT, theme.ACCENT_SUBTLE, theme.GLASS_HOVER, theme.CLEAR),
            animate = { background = theme.animation_ms },
            on_click = function(_, mouse_button)
                if mouse_button == "left" then
                    opts.on_select(value)
                end
            end,
            children = { cell(chosen:map(function(on)
                return { { text = format(value), bold = on } }
            end), tint(theme.ACCENT, theme.ACCENT, theme.FG, theme.DIM), theme.font.xs, {
                width = "Fill",
                align = "Center",
                align_v = "Center",
                animate = { foreground = theme.animation_ms },
            }) },
        }
    end
    -- Hairlines between segments, none at the ends: the bar's ring closes those.
    local children = util.lift(opts.options, function(values)
        local out = {}
        for index, value in ipairs(values) do
            if index > 1 then
                out[#out + 1] = rect { width = theme.border_width, height = "Fill", background = theme.GLASS_BORDER }
            end
            out[#out + 1] = segment(value)
        end
        return out
    end)
    return row {
        width = opts.width or "Fill",
        height = opts.height or theme.control.md,
        align_v = "Center",
        visible = opts.visible,
        radius = theme.radius.md,
        clip = "Rounded",
        background = theme.GLASS_CONTENT,
        border_width = theme.border_width,
        border_color = theme.GLASS_BORDER,
        children = children,
    }
end
