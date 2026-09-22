local theme = require("config.theme")
local cell = require("components.cell")
local panel_card = require("components.panel_card")
local util = require("lib.util")
local ui_state = require("lib.ui_state")

local function text_line(content, color, font, options)
    return cell(content, color or theme.TOOLTIP_FG, font or theme.font.sm, options)
end

local function children_for(opts)
    if opts.children ~= nil then
        return opts.children
    end
    local children = { text_line(opts.text) }
    for _, name in ipairs({ "detail", "secondary" }) do
        local content = opts[name]
        if content ~= nil then
            children[#children + 1] = text_line(
                content,
                opts[name .. "_color"] or theme.DIM,
                opts[name .. "_font"] or theme.font.xs,
                opts[name .. "_options"]
            )
        end
    end
    return children
end

return function(opts)
    local hovered = hover(opts.slot)
    local shown = computed({ hovered, ui_state.panel_open, ui_state.active_modal }, function(is_hovered, panel_open, active_modal)
        return is_hovered and active_modal == "" and (opts.in_panel or not panel_open)
    end)
    local lingering = util.linger(shown, theme.animation_ms)
    local shown_opacity = shown:map(function(is_shown)
        return is_shown and 1 or 0
    end)
    return popup {
        id = opts.id,
        parent = "bar",
        anchor_rect = hover_rect(opts.slot),
        visible = lingering,
        min_width = theme.control_width_lg,
        min_height = theme.control.md,
        width = opts.width,
        height = opts.height,
        grab = false,
        anchor = "Bottom",
        gravity = "Bottom",
        constraint_adjustment = { "FlipY", "SlideX" },
        offset = { x = 0, y = theme.panel_gap },
        child = panel_card(children_for(opts), {
            opacity = shown_opacity,
            animate = { opacity = theme.animation_ms },
            background = theme.GLASS_SURFACE,
            blur = true,
            border_width = theme.border_width,
            border_color = theme.GLASS_BORDER,
            padding = {
                top = opts.padding_v or theme.spacing.xs,
                right = theme.spacing.sm,
                bottom = opts.padding_v or theme.spacing.xs,
                left = theme.spacing.sm,
            },
        }),
    }
end
