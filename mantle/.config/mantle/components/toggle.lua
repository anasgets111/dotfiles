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
local switch = require("components.switch")

---@param slot string A `hover` slot unique to this switch.
---@param label? string Drawn in place of "On"/"Off"; the pill then sizes to it.
return function(signal, read, on_change, slot, label)
    local on = signal:map(function(value)
        return util.read_bool(value, read)
    end)
    local node, tint = switch(on, slot, function()
        on_change(not util.read_bool(signal:get(), read))
    end, {
        width = label == nil and theme.control_width_lg or nil,
        height = theme.control.sm,
        radius = theme.control.sm / 2,
    })
    node.padding = label and { left = theme.spacing.md, right = theme.spacing.md } or nil
    node.children = { cell(label or util.choose(on, "On", "Off"),
        tint(theme.ACCENT, theme.ACCENT, theme.FG, theme.DIM), theme.font.xs, {
            bold = on,
            width = "fill",
            align = "center",
            align_v = "center",
            animate = { foreground = theme.animation_ms },
        }) }
    return rect(node)
end
