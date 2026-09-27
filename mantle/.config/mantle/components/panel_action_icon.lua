-- A row's small control, tinted by what it does, with no ground until hover. Red disconnects or
-- forgets. It stays quieter than `components/icon_button.lua`, so a six-row list with two per row
-- does not read as a wall of buttons.
local theme = require("config.theme")
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
            local base = is_active and theme.ACCENT_MEDIUM or tint
            local opacity = is_active and theme.opacity.light or theme.opacity.muted
            return is_hovered and base or theme.with_opacity(base, opacity)
        end)
    elseif active then
        foreground = hovered:map(function(is_hovered)
            return is_hovered and theme.ACCENT_MEDIUM or theme.with_opacity(theme.ACCENT_MEDIUM, theme.opacity.light)
        end)
    else
        foreground = hovered:map(function(is_hovered)
            return is_hovered and tint or theme.with_opacity(tint, theme.opacity.muted)
        end)
    end

    local opacity
    if disabled_live then
        opacity = disabled:map(function(off)
            return off and theme.opacity.disabled or 1
        end)
    elseif disabled then
        opacity = theme.opacity.disabled
    end

    return icon_button(glyph, on_activate and function()
        local off = false
        if disabled_live then
            off = disabled:get() == true
        elseif disabled then
            off = true
        end
        if not off then
            on_activate()
        end
    end, {
        slot = opts.slot,
        size = theme.control[step],
        icon_size = theme.icon[step],
        radius = theme.radius.sm,
        border = false,
        background = theme.CLEAR,
        background_hover = theme.with_opacity(tint, theme.opacity.subtle),
        foreground = foreground,
        visible = opts.visible,
        spinning = opts.spinning,
        opacity = opacity,
    })
end
