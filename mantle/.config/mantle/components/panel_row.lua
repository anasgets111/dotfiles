-- Panel-list row: leading icon, title, optional subtitle, trailing action slot. `width = "Fill"`
-- keeps the trailing slot at the right edge and elides the title.
--
-- `selected` gets a ring, a tinted ground and an accent title; colour alone reads as a different
-- kind of row. Without `on_activate` this is a `rect`, not a no-op `button` that would take the
-- pointer and look clickable, and both shapes share the look.
local theme = require("config.theme")
local cell = require("components.cell")
local glyph = require("components.glyph")

-- Typed like `components/cell.lua`: without these shapes a `list` `itemfn`'s `any` reaches
-- `text.content` unchanged, a notification span array included.
---@class PanelRowOpts
---@field title string|Bound
---@field subtitle? string|Bound
---@field icon? string|Bound A glyph drawn as text and recoloured with the row.
---@field art? string|Bound A theme name or absolute path drawn as an `icon`, never recoloured.
---@field leading? Node A composed leading slot in place of `icon`/`art`: a glyph with a badge beside it.
---@field color? Color|Bound
---@field icon_color? Color|Bound
---@field selected? boolean
---@field opacity? number|Bound
---@field height? integer
---@field slot? string
---@field visible? boolean|Bound
---@field trailing? Node
---@field on_activate? fun()

---@param opts PanelRowOpts
return function(opts)
    local title_color = opts.selected and theme.ACCENT or (opts.color or theme.FG)
    ---@type string|TextRun[]|Bound
    local title = opts.title
    if opts.selected and type(title) == "string" then
        title = { { text = title, bold = true } }
    end
    local title_lines = { cell(title, title_color, theme.font.sm, {
        width = "Fill",
        animate = { foreground = theme.animation_ms },
    }) }
    if opts.subtitle then
        title_lines[#title_lines + 1] = cell(opts.subtitle, theme.DIM, theme.font.xs, { width = "Fill" })
    end

    local children = {}
    if opts.leading then
        children[#children + 1] = opts.leading
    elseif opts.icon then
        -- A glyph, not a themed icon, which `PaintStyle::Icon` cannot tint; `opts.art` is artwork.
        children[#children + 1] = glyph(opts.icon, opts.icon_color or title_color, theme.icon.md, {
            align_v = "Center",
            animate = { foreground = theme.animation_ms },
        })
    elseif opts.art then
        children[#children + 1] = icon { name = opts.art, size = theme.icon.md, align_v = "Center" }
    end
    children[#children + 1] = column { width = "Fill", align_v = "Center", children = title_lines }
    if opts.trailing then
        opts.trailing.align_v = opts.trailing.align_v or "Center"
        children[#children + 1] = opts.trailing
    end

    local body = row {
        width = "Fill",
        spacing = theme.spacing.sm,
        align_v = "Center",
        padding = { left = theme.spacing.sm, right = theme.spacing.sm },
        children = children,
    }

    local hovered = (opts.on_activate and opts.slot) and hover(opts.slot) or nil
    ---@type Color|Signal|nil
    local ground = opts.selected and theme.ACCENT_SUBTLE or nil
    -- Selection outranks the pointer, so a selected row keeps one ground and never lifts on hover.
    if hovered and not opts.selected then
        ground = hovered:map(function(is_hovered)
            return is_hovered and theme.GLASS_HOVER or nil
        end)
    end

    local shell = {
        hover = hovered,
        width = "Fill",
        height = opts.height or theme.control.lg,
        align_v = "Center",
        radius = theme.radius.md,
        visible = opts.visible,
        opacity = opts.opacity,
        background = ground,
        border_width = opts.selected and theme.border_width or nil,
        border_color = opts.selected and theme.ACCENT or nil,
        animate = {
            background = theme.animation_ms,
            border_color = theme.animation_ms,
            opacity = { duration = theme.animation_ms, easing = "OutCubic" },
        },
        children = { body },
    }
    if opts.on_activate == nil then
        return rect(shell)
    end
    shell.on_click = function(_, mouse_button)
        if mouse_button == "left" then
            opts.on_activate()
        end
    end
    return button(shell)
end
