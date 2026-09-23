-- The head of an expandable widget: bold title, a filling middle the caller supplies, and a chevron
-- following `expanded`, which a click toggles. Accent while open, glass while closed, each lifting
-- under the pointer. `ink` is the title and chevron only; a middle child brings its own colour.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local glyph = require("components.glyph")
local util = require("lib.util")

---@param expanded StateSignal<boolean> The widget's own `state`, toggled by a left click.
---@param slot string A `hover` slot unique to this header.
---@param title string|Bound
---@param middle? table The filling child between title and chevron; a spacer without one.
---@param opts? { visible?: boolean|Bound }
return function(expanded, slot, title, middle, opts)
    local hovered = hover(slot)
    -- Open picks the first pair, closed the second; each pair is hovered, then resting.
    local function tint(open_hot, open_rest, hot, rest)
        return computed({ expanded, hovered }, function(open, is_hot)
            if open then
                return is_hot and open_hot or open_rest
            end
            return is_hot and hot or rest
        end)
    end
    local ink = tint(theme.ACCENT, theme.ACCENT, theme.TEXT_ACTIVE, theme.FG)
    return button {
        width = "Fill",
        height = theme.item_height,
        radius = theme.radius.md,
        visible = opts and opts.visible,
        hover = hovered,
        background = tint(theme.ACCENT_LIGHT, theme.ACCENT_SUBTLE, theme.GLASS_HOVER, theme.GLASS_CONTENT),
        border_width = theme.border_width,
        border_color = tint(theme.ACCENT_MEDIUM, theme.ACCENT_MEDIUM, theme.GLASS_BORDER_HOVER, theme.GLASS_BORDER),
        animate = { background = theme.animation_ms, border_color = theme.animation_ms },
        on_click = function(_, mouse_button)
            if mouse_button == "left" then
                expanded:set(not expanded:get())
            end
        end,
        children = { row {
            width = "Fill",
            height = "Fill",
            align_v = "Center",
            spacing = theme.spacing.sm,
            padding = { left = theme.spacing.md, right = theme.spacing.md },
            children = {
                cell(util.bold(title), ink, theme.font.sm, {
                    align_v = "Center",
                    animate = { foreground = theme.animation_ms },
                }),
                middle or rect { width = "Fill" },
                glyph(expanded:map(function(open)
                    return open and icons.chevron_down or icons.chevron_right
                end), ink, theme.icon.sm, {
                    align_v = "Center",
                    animate = { foreground = theme.animation_ms },
                }),
            },
        } },
    }
end
