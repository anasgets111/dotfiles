local theme = require("config.theme")
local cell = require("components.cell")
local panel_card = require("components.panel_card")
local util = require("lib.util")
local ui_state = require("lib.ui_state")

-- Centred, because the card is a column of content-sized lines, and a short title over a longer state
-- line would otherwise pack against the left edge. `column` reads a child's `align_h` on the cross
-- axis, which `cell`'s `align` sets.
local function text_line(content, color, font, visible)
    return cell(content, color, font, { align = "Center", visible = visible })
end

local function children_for(opts)
    if opts.children ~= nil then
        return opts.children
    end
    for _, name in ipairs(opts.lines and { "text", "detail", "secondary" } or {}) do
        opts[name] = opts.lines:map(function(lines) return lines[name] end)
    end
    local children = { text_line(opts.text, theme.TOOLTIP_FG, theme.font.sm) }
    -- An empty `detail` or `secondary` hides rather than leaving a blank row.
    for _, name in ipairs({ "detail", "secondary" }) do
        if opts[name] ~= nil then
            children[#children + 1] = text_line(opts[name], theme.DIM, theme.font.xs,
                util.lift(opts[name], function(line)
                    return line ~= ""
                end))
        end
    end
    return children
end

-- `opts.group` serves a slot of buttons sharing one card. It is the key `util.track_hover` holds for
-- the button under the pointer, `""` between them, and `opts.group_prefix .. key` is that button's
-- hover slot. The held key keeps the card on the last button while it fades.
return function(opts)
    local group = opts.group
    local hovered = hover(opts.slot)
    if group then
        hovered = computed({ hovered, group }, function(is_hovered, name)
            return is_hovered and name ~= ""
        end)
    end
    local shown = computed({ hovered, ui_state.panel_open, ui_state.active_modal },
        function(is_hovered, panel_open, active_modal)
            return is_hovered and active_modal == "" and (opts.in_panel or not panel_open)
        end)
    return popup {
        id = opts.id,
        parent = "bar",
        -- Before the first hover a popup still refuses a zero rect.
        anchor_rect = group and util.hold(group):map(function(name)
            return name ~= "" and hover_rect(opts.group_prefix .. name):get() or { x = 0, y = 0, width = 1, height = 1 }
        end) or hover_rect(opts.slot),
        visible = util.linger(shown, theme.animation_ms),
        min_width = theme.control_width_lg,
        min_height = theme.control.md,
        width = opts.width,
        height = opts.height,
        grab = false,
        anchor = "Bottom",
        gravity = "Bottom",
        constraint_adjustment = { "FlipY", "SlideX" },
        offset = { x = 0, y = theme.spacing.xs },
        child = panel_card(children_for(opts), {
            opacity = shown:map(function(is_shown)
                return is_shown and 1 or 0
            end),
            animate = { opacity = theme.animation_ms },
            background = theme.GLASS_SURFACE,
            blur = true,
            border_width = theme.border_width,
            border_color = theme.GLASS_BORDER,
            padding = {
                top = opts.padding_v or theme.spacing.xs,
                bottom = opts.padding_v or theme.spacing.xs,
                right = theme.spacing.sm,
                left = theme.spacing.sm,
            },
        }),
    }
end
