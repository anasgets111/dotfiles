-- Quiet row actions take their tint on hover. Active modes keep an accent glyph and ground.
local theme = require("config.theme")
local util = require("lib.util")
local icon_button = require("components.icon_button")

---@param glyph string|Bound A `text` glyph, or a signal of one for a control whose icon follows state.
---@param on_activate fun()?
---@param opts { slot: string, tint?: Color, visible?: boolean|Bound, size?: "sm"|"md", disabled?: Signal|boolean, spinning?: Signal, active?: Signal|boolean }
return function(glyph, on_activate, opts)
    local tint = opts.tint or theme.FG
    -- `"md"` is the media panel's one transport control that is the row's subject.
    local step = opts.size or "sm"
    -- The same slot as `icon_button`'s, so the glyph brightens with the button's hover.
    local hovered = hover(opts.slot)
    -- `disabled` dims and ignores clicks, keeping the control's place in the row.
    local disabled = opts.disabled
    local disabled_live = type(disabled) == "userdata"

    local active = opts.active
    local foreground
    if type(active) == "userdata" then
        foreground = computed({ hovered, active }, function(is_hovered, is_active)
            return is_active and theme.ACCENT
                or is_hovered and tint or theme.with_opacity(theme.FG, theme.opacity.muted)
        end)
    elseif active then
        foreground = theme.ACCENT
    else
        foreground = hovered:map(function(is_hovered)
            return is_hovered and tint or theme.with_opacity(theme.FG, theme.opacity.muted)
        end)
    end

    local opacity = disabled and util.lift(disabled, function(off)
        return off and theme.opacity.disabled or 1
    end) or nil

    return icon_button(glyph, on_activate and function()
        if not disabled or (disabled_live and disabled:get() ~= true) then
            on_activate()
        end
    end, {
        slot = opts.slot,
        size = theme.control[step],
        icon_size = theme.icon[step],
        radius = theme.radius.sm,
        border = false,
        background = util.lift(active, function(on)
            return on and theme.ACCENT_SUBTLE or theme.CLEAR
        end),
        background_hover = util.lift(active, function(on)
            return on and theme.ACCENT_LIGHT or theme.with_opacity(tint, theme.opacity.subtle)
        end),
        foreground = foreground,
        visible = opts.visible,
        spinning = opts.spinning,
        opacity = opacity,
    })
end
