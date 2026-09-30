-- One circle shows session holds and adds a manual hold on click; right-click opens
-- `modules/global/idle_settings.lua`. The glyph swaps on the manual hold, since the cup means "I asked
-- for this". The accent ground means a confirmed hold; a tint marks an old compositor answer.
local util = require("lib.util")
local theme = require("config.theme")
local icons = require("config.icons")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local idle = require("lib.idle")

local SLOT = "idle"

local indicator = icon_button(util.choose(idle.manual, icons.awake, icons.idle), nil, {
    slot = SLOT,
    selected = ui_state.modal_showing("idle_settings"),
    background = computed({ idle.inhibited, idle.unconfirmed }, function(held, uncertain)
        return uncertain and theme.ACCENT_SUBTLE or held and theme.ACCENT or theme.GLASS_CONTROL
    end),
    on_buttons = {
        right = function() ui_state.toggle_modal("idle_settings") end,
        left = function() idle.set_manual(not idle.manual:get()) end,
    },
})

-- What holds it, then what happens next if nothing does.
local idle_tooltip = tooltip({
    slot = SLOT,
    text = computed({ idle.reasons, idle.inhibited, idle.stale }, idle.held_text),
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

return { indicator = indicator, tooltips = { idle_tooltip } }
