-- Shared panel and modal navigation; domain modules own their contents.
local M = {}

local util = require("lib.util")
local theme = require("config.theme")
local disclosure = require("lib.disclosure")
local notification_state = require("lib.notification_state")
local network_join = require("lib.network_join")

-- The bar host uses only x to clamp its card to the output.
M.popup_anchor = state("popup_anchor", { x = 0, y = 0, width = 70, height = 24 })

M.panel_open = state("panel_open", false)
M.panel_kind = state("panel_kind", "")
M.panel_instance = state("panel_instance", 0)

-- One string permits only one modal and makes `mantle toggle modal launcher` a single keybind.
M.active_modal = state("modal", "")

function M.panel_is(kind)
    return M.panel_open:get() and M.panel_kind:get() == kind
end

-- Leaving history marks its feed read, including a switch to another panel.
local function leave_panel()
    local kind = M.panel_open:get() and M.panel_kind:get()
    if kind == "bluetooth" then
        mantle.bluetooth:stop_discovery()
    elseif kind == "notifications" then
        notification_state.mark_popups_seen()
    end
end

function M.close_panel()
    leave_panel()
    M.panel_open:set(false)
    network_join.clear_network_prompts()
end

function M.open_panel(kind, rect)
    local was_open = M.panel_open:get()
    if was_open and M.panel_kind:get() == kind then
        M.popup_anchor:set(rect)
        return
    end
    if kind == "notifications" then
        notification_state.open_history()
    end
    -- A pending password left standing would keep the surface `exclusive` over a fieldless panel.
    network_join.clear_network_prompts()
    leave_panel()
    disclosure.reset()
    -- A panel and a modal never share the screen.
    M.active_modal:set("")
    M.popup_anchor:set(rect)
    M.panel_kind:set(kind)
    if not was_open then
        M.panel_instance:set(M.panel_instance:get() + 1)
    end
    M.panel_open:set(true)
    if kind == "bluetooth" then
        mantle.bluetooth:start_discovery()
    end
end

function M.toggle_panel(kind, rect)
    if M.panel_is(kind) then
        M.close_panel()
        return
    end
    M.open_panel(kind, rect)
end

local media_hover = state("media_hover", { trigger = false, panel = false })
local media_close_timer

function M.set_media_hover(region, inside)
    media_hover:set(util.with(media_hover:get(), region, inside == true))
    local media_open = M.panel_is("media")
    if media_close_timer and (inside or media_open) then
        media_close_timer:cancel()
        media_close_timer = nil
    end
    if inside or not media_open then
        return
    end
    media_close_timer = timer(theme.animation_slow_ms, function()
        media_close_timer = nil
        local hovered = media_hover:get()
        if not hovered.trigger and not hovered.panel and M.panel_is("media") then
            M.close_panel()
        end
    end)
end

-- Drives the indicator rings. Both signals: `panel_kind` survives close.
function M.panel_showing(kind)
    return computed({ M.panel_open, M.panel_kind }, function(open, current)
        return open and current == kind
    end)
end

function M.modal_showing(kind)
    return M.active_modal:map(function(current)
        return current == kind
    end)
end

-- Includes modal changes made through `mantle toggle`.
M.active_modal:on_change(function(kind)
    if kind ~= "" and M.panel_open:get() then
        M.close_panel()
    end
end)

-- Closing includes Escape, a click, `mantle toggle`, and replacement by another modal.
function M.on_modal_close(kind, fn)
    M.active_modal:on_change(function(_, before)
        if before == kind then
            fn()
        end
    end)
end

-- A delayed close must not dismiss a later modal.
function M.close_modal(kind)
    if M.active_modal:get() == kind then
        M.active_modal:set("")
    end
end

function M.toggle_modal(kind)
    M.active_modal:set(M.active_modal:get() == kind and "" or kind)
end

return M
