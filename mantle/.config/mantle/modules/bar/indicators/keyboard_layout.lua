local theme = require("config.theme")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")

local SLOT = "keyboard_layout"

-- First two letters of the layout name, uppercased: "English (US)" -> "EN" and
-- "Arabic (Egypt)" -> "AR".
--
-- ponytail: this is wrong for any layout whose first two letters are not its short code, which is
-- most non-Latin scripts spelled in their own language. The upgrade is the XKB layout code, which
-- niri knows and `mantle.keyboard` does not carry; adding
-- it there is a capability change, not a config one.
local function layout_short(k)
    local name = (k and k.active_layout) or "?"
    return (name:gsub("[^%a]", ""):sub(1, 2)):upper()
end

local function next_layout()
    local k = mantle.keyboard:get()
    if k == nil or (k.layout_count or 0) < 2 then
        return
    end
    local next_index = ((k.active_layout_index or 0) + 1) % k.layout_count
    mantle.keyboard:invoke("switch_layout", next_index)
end

action("keyboard.next_layout", next_layout)

local indicator = icon_button(mantle.keyboard:map(layout_short), next_layout, {
    slot = SLOT,
    icon_size = theme.font.md,
    foreground = mantle.keyboard:map(function(k)
        return (k and k.caps_lock) and theme.PEACH or theme.FG
    end),
    -- One configured layout has nothing to change and a layout indicator need not be drawn.
    visible = mantle.keyboard:map(function(k)
        return k ~= nil and (k.layout_count or 0) >= 2
    end),
})

local layout_tooltip = tooltip({ id = "keyboard_layout_tooltip", slot = SLOT, text = mantle.keyboard:map(function(k)
    return k ~= nil and k.active_layout ~= "" and k.active_layout or "Keyboard layout unavailable"
end) })

return { indicator = indicator, tooltip = layout_tooltip }
