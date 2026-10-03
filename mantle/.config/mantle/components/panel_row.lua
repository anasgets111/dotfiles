-- Panel-list row with a leading icon, title, optional subtitle and trailing action slot.
-- `width = "fill"` keeps the trailing slot at the right edge and elides the title.
--
-- `selected` gets a ring, a tinted ground and an accent title; colour alone reads as a different
-- kind of row. Rows without `on_activate` leave clicks to their children or parent.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local reveal = require("components.reveal")

-- Typed like `components/cell.lua`. Without these shapes a `list` `itemfn`'s `any` reaches
-- `text.content` unchanged, a notification span array included.
---@class PanelRowOpts
---@field title string|TextRun[]|Bound
---@field subtitle? string|TextRun[]|Bound Runs let a summary tint its parts, such as a hot CPU readout.
---@field icon? string|Bound A glyph drawn as text and recoloured with the row.
---@field leading? Node A composed leading slot in place of `icon`, such as a glyph with a badge beside it.
---@field color? Color|Bound
---@field icon_color? Color|Bound
---@field selected? boolean
---@field opacity? number|Bound
---@field height? integer
---@field title_size? integer Default `theme.font.sm`, a bar panel's row. A modal's rows take `md`.
---@field subtitle_size? integer Default `theme.font.xs`; `sm` under an `md` title.
---@field slot? string Required with animated details; names the measurement and hover.
---@field visible? boolean|Bound
---@field trailing? Node
---@field expanded? StateSignal<boolean> A disclosure row: a chevron after `trailing`, and a click toggles it. Required when `details` is set.
---@field details? Node Under the row while `expanded` is true, outside the button.
---@field animate_details? boolean Reveals details through an animated clipped height; the parent must size to content.
---@field details_spacing? integer Gap above `details`. Default `theme.spacing.xs`.
---@field on_activate? fun()

---@param opts PanelRowOpts
return function(opts)
    local expanded = opts.expanded
    if expanded then
        local chevron = glyph(util.choose(expanded, icons.chevron_down, icons.chevron_right), theme.DIM, theme.icon.sm,
            { align_v = "center" })
        opts.trailing = opts.trailing
            and row { spacing = theme.spacing.xs, align_v = "center", children = { opts.trailing, chevron } }
            or chevron
        opts.on_activate = function()
            expanded:set(not expanded:get())
        end
    end
    local title_color = opts.selected and theme.ACCENT or (opts.color or theme.FG)
    ---@type string|TextRun[]|Bound
    local title = opts.title
    if opts.selected and type(title) == "string" then
        title = { { text = title, bold = true } }
    end
    local title_lines = { cell(title, title_color, opts.title_size or theme.font.sm, {
        width = "fill",
        animate = { foreground = theme.animation_ms },
    }) }
    if opts.subtitle then
        title_lines[#title_lines + 1] = cell(opts.subtitle, theme.DIM, opts.subtitle_size or theme.font.xs,
            { width = "fill" })
    end

    local children = {}
    if opts.leading then
        children[#children + 1] = opts.leading
    elseif opts.icon then
        -- A glyph, not a themed icon, which `PaintStyle::Icon` cannot tint.
        children[#children + 1] = glyph(opts.icon, opts.icon_color or title_color, theme.icon.md, {
            align_v = "center",
            animate = { foreground = theme.animation_ms },
        })
    end
    children[#children + 1] = column { width = "fill", align_v = "center", children = title_lines }
    if opts.trailing then
        opts.trailing.align_v = opts.trailing.align_v or "center"
        children[#children + 1] = opts.trailing
    end

    local body = row {
        width = "fill",
        spacing = theme.spacing.sm,
        align_v = "center",
        padding = { left = theme.spacing.sm, right = theme.spacing.sm },
        children = children,
    }

    local hovered = (opts.on_activate and opts.slot) and hover(opts.slot) or nil
    ---@type Color|Signal|nil
    local ground = opts.selected and theme.ACCENT_SUBTLE or nil
    -- Selection outranks the pointer, so a selected row keeps one ground and never lifts on hover.
    if hovered and not opts.selected then
        ground = util.choose(hovered, theme.GLASS_HOVER, nil)
    end

    local shell = {
        hover = hovered,
        width = "fill",
        height = opts.height or theme.control.lg,
        align_v = "center",
        radius = theme.radius.md,
        visible = opts.details == nil and opts.visible or nil,
        opacity = opts.opacity,
        background = ground,
        border_width = opts.selected and theme.border_width or nil,
        border_color = opts.selected and theme.ACCENT or nil,
        animate = {
            background = theme.animation_ms,
            border_color = theme.animation_ms,
            opacity = { duration = theme.animation_ms, easing = "out_cubic" },
        },
        children = { body },
    }
    if opts.on_activate ~= nil then
        shell.on_click = function(_, mouse_button)
            if mouse_button == "left" then
                opts.on_activate()
            end
        end
    end
    local control = rect(shell)
    if opts.details == nil then
        return control
    end
    assert(expanded, "panel_row details require expanded")
    if not opts.animate_details then
        opts.details.visible = expanded
        return column {
            width = "fill",
            spacing = opts.details_spacing or theme.spacing.xs,
            visible = opts.visible,
            children = { control, opts.details },
        }
    end
    assert(opts.slot, "panel_row details require a slot")
    return reveal(control, opts.details, expanded, {
        slot = opts.slot,
        spacing = opts.details_spacing,
        visible = opts.visible,
    })
end
