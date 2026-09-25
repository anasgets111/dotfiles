-- One surface for the scrim, outside-click catcher and every modal: a surface per modal doubled the
-- scrim while cross-fading, and same-layer order is the compositor's, so a separate scrim ate clicks.
local theme = require("config.theme")
local util = require("lib.util")
local ui_state = require("lib.ui_state")

local modals = {
    require("modules.global.launcher"),
    require("modules.global.wallpaper_picker"),
    require("modules.global.idle_settings"),
    (require("modules.global.rescue_details")),
}

local any_modal = ui_state.active_modal:map(function(kind)
    return kind ~= ""
end)

-- Mapped through the last card's exit fade. `keyboard_interactivity` reads the same signal: `None`
-- on a still-mapped host makes Hyprland refocus the last window, onto its workspace.
local shown = util.linger(any_modal, theme.animation_ms)

-- Only cards open or fading out are children: a hidden card would be frozen, not dropped.
local lingering = {}
for _, modal in ipairs(modals) do
    table.insert(lingering, util.linger(ui_state.modal_showing(modal.kind), theme.animation_ms))
end

local escape_sink = textfield {
    id = "escape_sink",
    width = 0,
    height = 0,
    autofocus = true,
    on_change = function() end,
    on_cancel = function()
        ui_state.close_modal(ui_state.active_modal:get())
    end,
}

local cards = computed(lingering, function(...)
    local open = {}
    for index, modal in ipairs(modals) do
        if select(index, ...) then
            table.insert(open, modal.node)
        end
    end
    table.insert(open, escape_sink)
    return open
end)

return panel {
    id = "modal_host",
    -- One instance, on the output the compositor picks at each show.
    monitor = "Active",
    namespace = "mantle-modal-host",
    layer = "Top",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive = false,
    width = "Fill",
    height = "Fill",
    visible = shown,
    -- Released by the unmap, costing `theme.animation_ms` of swallowed typing; a stray workspace
    -- switch is worse. `OnDemand`, not `Exclusive`: Hyprland sends the pointer only to an exclusive
    -- layer, so the bar went dead. Both compositors still focus an on-demand layer when it maps.
    keyboard_interactivity = shown:map(function(open)
        return open and "OnDemand" or "None"
    end),
    child = rect {
        width = "Fill",
        height = "Fill",
        children = {
            -- Dims, not blurs: cards blur themselves, and a blur region cannot fade.
            rect {
                width = "Fill",
                height = "Fill",
                background = theme.SCRIM,
                opacity = any_modal:map(function(open)
                    return open and 1 or 0
                end),
                animate = any_modal:map(function(open)
                    return {
                        opacity = { duration = theme.animation_ms, easing = open and "OutCubic" or "InCubic", from = 0 },
                    }
                end),
            },
            -- The catcher contains the cards rather than sitting under them: `hit::descend` stops at
            -- the first child containing the point.
            button {
                width = "Fill",
                height = "Fill",
                cursor = "default",
                on_click = function()
                    ui_state.close_modal(ui_state.active_modal:get())
                end,
                children = cards,
            },
        },
    },
}
