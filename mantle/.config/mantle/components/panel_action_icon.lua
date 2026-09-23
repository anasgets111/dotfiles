-- A row's small control: tinted by what it does, red to disconnect or forget, with no ground until
-- hover. It stays quieter than `components/icon_button.lua`; two per six-row list must not read as
-- eighteen buttons.
local theme = require("config.theme")
local icon_button = require("components.icon_button")

-- Fully transparent; `border = false` also disables `icon_button`'s ring.
local CLEAR = "#00000000"

---@param glyph string|Bound A `text` glyph, or a signal of one for a control whose icon follows state.
---@param on_activate fun()?
---@param opts { slot: string, tint?: Color, visible?: boolean|Bound, size?: "sm"|"md", disabled?: Signal }
return function(glyph, on_activate, opts)
    local tint = opts.tint or theme.FG
    -- `"md"` is the media panel's one transport control that is the row's subject.
    local step = opts.size or "sm"
    -- The same slot as `icon_button`'s, so the glyph brightens with the button's hover.
    local hovered = hover(opts.slot)
    -- `disabled` dims and ignores clicks, keeping the control's place in the row.
    local disabled = opts.disabled
    return icon_button(glyph, on_activate and function()
        if not (disabled and disabled:get()) then
            on_activate()
        end
    end, {
        slot = opts.slot,
        size = theme.control[step],
        icon_size = theme.icon[step],
        radius = theme.radius.sm,
        border = false,
        background = CLEAR,
        background_hover = theme.with_opacity(tint, theme.opacity.subtle),
        foreground = hovered:map(function(is_hovered)
            return is_hovered and tint or theme.with_opacity(tint, theme.opacity.disabled)
        end),
        visible = opts.visible,
        opacity = disabled and disabled:map(function(off)
            return off and theme.opacity.disabled or 1
        end),
    })
end
