local theme = require("config.theme")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")

local SLOT = "keyboard_layout"

-- First two letters of the layout name, uppercased, so "English (US)" reads "EN".
-- ponytail: wrong for any layout whose first two letters are not its short code, which is most
-- non-Latin scripts named in their own language. The fix is the XKB code, which `mantle.keyboard`
-- would have to carry.
local function layout_short(keyboard)
    return (((keyboard and keyboard.active_layout) or "?"):gsub("[^%a]", ""):sub(1, 2)):upper()
end

local function next_layout()
    local keyboard = mantle.keyboard:get()
    if keyboard == nil or (keyboard.layout_count or 0) < 2 then
        return
    end
    mantle.keyboard:invoke("switch_layout", ((keyboard.active_layout_index or 0) + 1) % keyboard.layout_count)
end

action("keyboard.next_layout", next_layout)

local indicator = icon_button(mantle.keyboard:map(layout_short), next_layout, {
    slot = SLOT,
    icon_size = theme.font.md,
    foreground = mantle.keyboard:map(function(keyboard)
        return (keyboard and keyboard.caps_lock) and theme.PEACH or theme.FG
    end),
    -- One configured layout has nothing to switch to.
    visible = mantle.keyboard:map(function(keyboard)
        return keyboard ~= nil and (keyboard.layout_count or 0) >= 2
    end),
})

local layout_tooltip = tooltip({
    id = "keyboard_layout_tooltip",
    slot = SLOT,
    text = mantle.keyboard:map(function(keyboard)
        return keyboard ~= nil and keyboard.active_layout ~= "" and keyboard.active_layout or
            "Keyboard layout unavailable"
    end)
})

return { indicator = indicator, tooltip = layout_tooltip }
