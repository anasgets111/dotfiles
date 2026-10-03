-- One surface for the scrim, outside-click catcher and every modal: a surface per modal doubled the
-- scrim while cross-fading, and same-layer order is the compositor's, so a separate scrim ate clicks.
local theme = require("config.theme")
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local scrim = require("components.scrim")

local modals = {
    require("modules.global.launcher"),
    require("modules.global.wallpaper_picker"),
    require("modules.global.idle_settings"),
    (require("modules.global.rescue_details")),
}

local any_modal = ui_state.active_modal:map(function(kind)
    return kind ~= ""
end)

-- Only cards open or fading out are children: a hidden card would be frozen, not dropped.
local lingering = {}
-- Scrolls only: a state reset here would miss a switch between modals, so each modal resets its
-- state with `ui_state.on_modal_close`.
local reset = {}
for _, modal in ipairs(modals) do
    table.insert(lingering, util.linger(ui_state.modal_showing(modal.kind), theme.animation_ms))
    reset = util.concat(reset, modal.reset_on_close)
end

-- Mapped through the last card's exit fade. `keyboard_interactivity` reads the same signal: `None`
-- on a still-mapped host makes Hyprland refocus the last window, onto its workspace.
local shown = util.linger(any_modal, theme.animation_ms)

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
    output = "Active",
    namespace = "mantle-modal-host",
    layer = "Top",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive_zone = false,
    width = "Fill",
    height = "Fill",
    visible = shown,
    reset_on_close = reset,
    -- Released by the unmap, costing `theme.animation_ms` of swallowed typing; a stray workspace
    -- switch is worse. `Exclusive` on niri, where a workspace switch hands an on-demand layer's keys
    -- to a window. `OnDemand` on Hyprland, which sends the pointer only to an exclusive layer and
    -- killed the bar; it still focuses an on-demand layer when it maps.
    keyboard_interactivity = computed({ shown, mantle.workspaces }, function(open, workspaces)
        if not open then
            return "None"
        end
        return workspaces and workspaces.compositor == "niri" and "Exclusive" or "OnDemand"
    end),
    child = rect {
        width = "Fill",
        height = "Fill",
        children = {
            -- Dims, not blurs: cards blur themselves, and a blur region cannot fade.
            scrim(any_modal),
            -- The catcher contains the cards rather than sitting under them: `hit::descend` stops at
            -- the first child containing the point.
            rect {
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
