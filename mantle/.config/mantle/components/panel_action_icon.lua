-- Quiet row actions take their tint on hover. Active modes keep an accent glyph and ground.
local theme = require("config.theme")
local util = require("lib.util")
local icon_button = require("components.icon_button")

---@param glyph string|Bound A `text` glyph, or a signal of one for a control whose icon follows state.
---@param on_activate fun()?
---@param opts { slot: string, tint?: Color, visible?: boolean|Bound, size?: "sm"|"md", disabled?: Signal, spinning?: Signal, active?: Signal }
return function(glyph, on_activate, opts)
    local tint = opts.tint or theme.FG
    -- `"md"` is the media panel's one transport control that is the row's subject.
    local step = opts.size or "sm"
    -- The same slot as `icon_button`'s, so the glyph brightens with the button's hover.
    local hovered = hover(opts.slot)
    -- `disabled` dims and ignores clicks, keeping the control's place in the row.
    local disabled = opts.disabled

    local active = opts.active
    local foreground
    if active then
        foreground = computed({ hovered, active }, function(is_hovered, is_active)
            return is_active and theme.ACCENT
                or is_hovered and tint or theme.with_opacity(theme.FG, theme.opacity.muted)
        end)
    else
        foreground = util.choose(hovered, tint, theme.with_opacity(theme.FG, theme.opacity.muted))
    end

    local opacity = disabled and util.choose(disabled, theme.opacity.disabled, 1) or nil

    return icon_button(glyph, on_activate and function()
        if not disabled or disabled:get() ~= true then
            on_activate()
        end
    end, {
        slot = opts.slot,
        size = theme.control[step],
        icon_size = theme.icon[step],
        radius = theme.radius.sm,
        border = false,
        background = util.choose(active, theme.ACCENT_SUBTLE, theme.CLEAR),
        background_hover = util.choose(active, theme.ACCENT_LIGHT, theme.with_opacity(tint, theme.opacity.subtle)),
        foreground = foreground,
        visible = opts.visible,
        spinning = opts.spinning,
        opacity = opacity,
    })
end
