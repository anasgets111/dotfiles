-- On/off switch for boolean writes, with the next capability snapshot as the only readback. Takes
-- the raw signal plus `read` (the caller knows which field), and hands `on_change` the flipped value.
--
-- A pill that says its state in a word, on the tile grounds `panel_toggle_card` uses, so it reads as
-- "Bluetooth · On" beside a title. A thumb track said nothing about what it switched. Fixed width, so
-- "On" and "Off" do not shift the row. Where the title is not the thing switched, `label` names it
-- and the pill lights like a tile: "Do not disturb" beside "Notifications".
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")

---@param slot string A `hover` slot unique to this switch.
---@param label? string Drawn in place of "On"/"Off"; the pill then sizes to it.
return function(signal, read, on_change, slot, label)
    local on = signal:map(function(value)
        return util.read_bool(value, read)
    end)
    local hovered = hover(slot)
    local tint = util.tint(on, hovered)
    return button {
        width = label == nil and theme.control_width_lg or nil,
        height = theme.control.sm,
        padding = label and { left = theme.spacing.md, right = theme.spacing.md } or nil,
        radius = theme.control.sm / 2,
        hover = hovered,
        background = tint(theme.ACCENT_LIGHT, theme.ACCENT_SUBTLE, theme.GLASS_HOVER, theme.GLASS_CONTENT),
        border_width = theme.border_width,
        border_color = tint(theme.ACCENT_MEDIUM, theme.ACCENT_MEDIUM, theme.GLASS_BORDER_HOVER, theme.GLASS_BORDER),
        animate = { background = theme.animation_ms, border_color = theme.animation_ms },
        on_click = function(_, mouse_button)
            if mouse_button == "left" then
                on_change(not util.read_bool(signal:get(), read))
            end
        end,
        children = { cell(on:map(function(checked)
            return { { text = label or (checked and "On" or "Off"), bold = checked } }
        end), tint(theme.ACCENT, theme.ACCENT, theme.FG, theme.DIM), theme.font.xs, {
            width = "Fill",
            align = "Center",
            align_v = "Center",
            animate = { foreground = theme.animation_ms },
        }) },
    }
end
