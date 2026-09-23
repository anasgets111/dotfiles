-- One circle shows session holds and adds a manual hold on click; right-click opens
-- `modules/global/idle_settings.lua`. The glyph swaps on the manual hold, since the cup means "I asked
-- for this". The accent ground means any hold, so media can light it without a glyph change.
local theme = require("config.theme")
local icons = require("config.icons")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local idle = require("lib.idle")

local SLOT = "idle"

local indicator = icon_button(idle.manual:map(function(manual)
    return manual and icons.awake or icons.idle
end), nil, {
    slot = SLOT,
    selected = ui_state.modal_showing("idle_settings"),
    background = idle.inhibited:map(function(held)
        return held and theme.ACCENT or theme.GLASS_CONTROL
    end),
    background_hover = idle.inhibited:map(function(held)
        return held and theme.ACCENT_HOVER or theme.GLASS_CONTROL_HOVER
    end),
    on_button = function(_, mouse_button)
        if mouse_button == "right" then
            ui_state.toggle_modal("idle_settings")
        elseif mouse_button == "left" then
            idle.set_manual(not idle.manual:get())
        end
    end,
})

-- What holds it, then what happens next if nothing does.
local idle_tooltip = tooltip({
    id = "idle_tooltip",
    slot = SLOT,
    text = computed({ idle.reasons, idle.inhibited }, idle.held_text),
    detail = computed({ idle.schedule, idle.arming, idle.manual, idle.enabled }, function(plan, arming, manual, on)
        if not on or plan.total == 0 then
            return "Click to hold · right-click for settings"
        end
        if manual then
            return "Click to drop the manual hold"
        end
        for _, entry in ipairs(plan.list) do
            if entry.key == arming.key then
                return string.format("%s in %s", entry.title, idle.clock(math.max(0, entry.delay - arming.elapsed)))
            end
        end
        return "Nothing is counting down"
    end),
})

return { indicator = indicator, tooltip = idle_tooltip }
