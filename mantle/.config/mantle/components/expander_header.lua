-- The head of an expandable widget: a bold title on the left, a filling middle the caller supplies,
-- and a chevron that follows `expanded`. Clicking it toggles that flag.
--
-- Extraction rule: one call site is a local; two agreeing call sites are a component. The weather
-- forecast and the system readout are the two, and their three state colours -- ground, ring and
-- ink -- have to agree or an open header reads as half open.
--
-- Accent while open, glass while closed, each lifting one step under the pointer. `ink` is the
-- title and the chevron only; a middle child brings its own colour, because the age of a weather
-- reading and a CPU percentage are not the same kind of text.
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
    local ground = computed({ expanded, hovered }, function(open, hot)
        if open then
            return hot and theme.ACCENT_LIGHT or theme.ACCENT_SUBTLE
        end
        return hot and theme.GLASS_HOVER or theme.GLASS_CONTENT
    end)
    local ring = computed({ expanded, hovered }, function(open, hot)
        if open then
            return theme.ACCENT_MEDIUM
        end
        return hot and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER
    end)
    local ink = computed({ expanded, hovered }, function(open, hot)
        if open then
            return theme.ACCENT
        end
        return hot and theme.TEXT_ACTIVE or theme.FG
    end)
    return button {
        width = "Fill",
        height = theme.item_height,
        radius = theme.radius.md,
        visible = opts and opts.visible,
        hover = hovered,
        background = ground,
        border_width = theme.border_width,
        border_color = ring,
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
