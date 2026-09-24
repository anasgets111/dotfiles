-- Shared view state: panels, modals, the network sheet and the notification cards. `on_click` hands
-- an indicator its rect, and the panel host reads it back from here.
--
-- `popup_anchor`: only `x` is read, since `panel_host` is a layer surface that clamps the card to the
-- output rather than a popup with `anchor_rect`/`gravity`. The shape is what `on_click` supplies.
local notifications = require("lib.notifications")
local util = require("lib.util")
local theme = require("config.theme")

local popup_anchor = state("popup_anchor", { x = 0, y = 0, width = 70, height = 24 })

-- `modules/shell/panel_host.lua`'s shared-surface signals: whether it is up and its current panel.
-- One surface serves every bar panel; one slot enforces that rather than five files coordinating.
local panel_open = state("panel_open", false)
local panel_kind = state("panel_kind", "")
local panel_instance = state("panel_instance", 0)

-- The one modal on screen, or `""`. One string, so two can never be open at once and
-- `mantle toggle modal launcher` is a single keybind.
local active_modal = state("modal", "")

-- Which notifications have had their popup turn. A view fact, since `dismiss` removes popup and
-- history together. Keyed by id plus timestamp, so `replaces_id` content pops again. Replaced
-- wholesale, which prunes gone entries.
local popup_seen = state("notification_popup_seen", {})

local function mark_popups_seen()
    local seen = {}
    for _, notification in ipairs((mantle.notifications:get() or {}).feed or {}) do
        seen[notifications.notification_key(notification)] = true
    end
    popup_seen:set(seen)
end

-- Joining a hidden network, which has no row to click: name, wait, password. `hidden_draft` is the
-- live field text, which a `textfield` only ever hands to `on_change`; `hidden_ssid` is it once
-- submitted. The password never passes through Lua.
local hidden_prompt = state("network_hidden_prompt", false)
local hidden_draft = state("network_hidden_draft", "")
local hidden_ssid = state("network_hidden_ssid", "")

-- Which step of the credential sheet is on screen, `""` for none; `panel_host` reads it for keyboard
-- focus. A password prompt outranks the hidden steps, since it answers a click on a listed row. The
-- end is read, not latched: a `computed` has no side effects, so `network.ssid` reaching the typed name
-- ends the sheet. A failure counts only when `connect_error` names that network, or another join's
-- leftover would flash first.
local credential_step = computed({ hidden_prompt, hidden_ssid, mantle.network }, function(active, name, network)
    if network and network.password_ssid ~= nil then
        return "password"
    end
    if not active then
        return ""
    end
    if name == "" then
        return "name"
    end
    if network and network.ssid == name then
        return ""
    end
    if network and network.connect_error ~= nil and network.connect_error.ssid == name then
        return "failed"
    end
    return "waiting"
end)

-- A hidden join's sheet replaces the access point list; a password for a listed row leaves it up.
local hidden_join = computed({ hidden_prompt, credential_step }, function(active, step)
    return active and step ~= ""
end)

-- Every way out of the sheet. `cancel_connect` is a no-op with nothing parked, so this is safe on
-- any closing edge.
local function clear_network_prompts()
    hidden_prompt:set(false)
    hidden_draft:set("")
    hidden_ssid:set("")
    mantle.network:invoke("cancel_connect")
end

-- Cancel also stops a join in flight; closing the panel does not, so a join survives it.
local function cancel_network_join()
    mantle.network:invoke("abort_connect")
    clear_network_prompts()
end

local function open_hidden_prompt()
    clear_network_prompts()
    hidden_prompt:set(true)
end

-- The MAC whose codec list is open in the bluetooth panel, or `""`; cleared when the panel closes.
local bluetooth_codec_for = state("bluetooth_codec_for", "")
-- Whether the audio panel's device pickers are expanded.
local audio_output_picker = state("audio_output_picker", false)
local audio_input_picker = state("audio_input_picker", false)
-- The updates panel's log view, so a reopened panel starts on its list.
local updates_log_open = state("updates_log_open", false)

local function panel_is(kind)
    return panel_open:get() and panel_kind:get() == kind
end

-- Leaving bluetooth stops discovery and closes its codec list; leaving audio collapses its pickers;
-- leaving updates closes its log.
local function leave_panel()
    local kind = panel_open:get() and panel_kind:get()
    if kind == "bluetooth" then
        mantle.bluetooth:invoke("stop_discovery")
        bluetooth_codec_for:set("")
    elseif kind == "audio" then
        audio_output_picker:set(false)
        audio_input_picker:set(false)
    elseif kind == "updates" then
        updates_log_open:set(false)
    end
end

-- The single close path, prompts included, rather than one in the click-outside catcher and one in
-- the toggle.
local function close_panel()
    -- Reading history counts as seeing its notifications. Mark on the way out, not only in, so
    -- arrivals while the panel was open do not get another popup turn.
    if panel_is("notifications") then
        mark_popups_seen()
    end
    leave_panel()
    panel_open:set(false)
    clear_network_prompts()
end

local function open_panel(kind, rect)
    local was_open = panel_open:get()
    if was_open and panel_kind:get() == kind then
        popup_anchor:set(rect)
        return
    end
    if kind == "notifications" then
        mark_popups_seen()
    end
    -- A pending password left standing would keep the surface `Exclusive` over a fieldless panel.
    clear_network_prompts()
    leave_panel()
    -- A panel and a modal never share the screen (`toggle_panel` clears `active_modal`).
    active_modal:set("")
    popup_anchor:set(rect)
    panel_kind:set(kind)
    if not was_open then
        panel_instance:set(panel_instance:get() + 1)
    end
    panel_open:set(true)
    if kind == "bluetooth" then
        mantle.bluetooth:invoke("start_discovery")
    end
end

local function toggle_panel(kind, rect)
    if panel_is(kind) then
        close_panel()
        return
    end
    open_panel(kind, rect)
end

local media_hover = state("media_hover", { trigger = false, panel = false })
local media_close_timer

local function set_media_hover(region, inside)
    media_hover:set(util.with(media_hover:get(), region, inside == true))
    local media_open = panel_is("media")
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
        if not hovered.trigger and not hovered.panel and panel_is("media") then
            close_panel()
        end
    end)
end

-- Drives the indicator rings. Both signals: `panel_kind` survives close.
local function panel_showing(kind)
    return computed({ panel_open, panel_kind }, function(open, current)
        return open and current == kind
    end)
end

local function modal_showing(kind)
    return active_modal:map(function(current)
        return current == kind
    end)
end

-- Opening a modal closes any panel; nothing else about the panel changes, so a re-open lands where
-- it was.
local function open_modal(kind)
    if panel_open:get() then
        close_panel()
    end
    active_modal:set(kind)
end

-- Closes `kind` only if it is the one showing, so a modal's own close cannot dismiss a later one.
local function close_modal(kind)
    if active_modal:get() == kind then
        active_modal:set("")
    end
end

local function toggle_modal(kind)
    if active_modal:get() == kind then
        close_modal(kind)
    else
        open_modal(kind)
    end
end

-- Which cards are open, shared so popup and history agree. Tables rather than a signal per group:
-- keys appear as notifications arrive, and minting registry entries at resolve time would grow the
-- session.
local expanded_groups = state("notification_expanded_groups", {})
local expanded_messages = state("notification_expanded_messages", {})

-- Reply draft, id (`0` for none) plus text. One slot, matching the Renderer's field buffer; the id
-- keeps Send on A from sending B's draft.
local reply_draft_id = state("notification_reply_draft_id", 0)
local reply_draft = state("notification_reply_draft", "")

local function toggle_key(signal, key)
    signal:set(util.with(signal:get(), key, not signal:get()[key]))
end

-- Store each keystroke (`textfield.on_change`), stamped with its card.
local function set_reply_draft(id, text)
    reply_draft_id:set(id)
    reply_draft:set(text or "")
end

-- Clear `id`'s draft; Escape's `on_cancel` and successful send both use this.
local function clear_reply(id)
    if reply_draft_id:get() == id then
        reply_draft_id:set(0)
        reply_draft:set("")
    end
end

-- Draft text belonging to a notification still in the feed. A surface binds
-- `keyboard_interactivity` to this, so the keyboard survives the pointer leaving mid-sentence.
local reply_pending = computed({ reply_draft_id, reply_draft, mantle.notifications }, function(id, text, inbox)
    if id == 0 or text == "" then
        return false
    end
    for _, notification in ipairs((inbox and inbox.feed) or {}) do
        if notification.id == id then
            return true
        end
    end
    return false
end)

-- Empty is a no-op: `reply` removes the notification either way, losing the card and sending nothing.
local function send_reply(id)
    local text = reply_draft:get()
    if reply_draft_id:get() ~= id or text == "" then
        return
    end
    mantle.notifications:invoke("reply", id, text)
    clear_reply(id)
end

return {
    popup_anchor = popup_anchor,
    popup_seen = popup_seen,
    expanded_groups = expanded_groups,
    expanded_messages = expanded_messages,
    reply_draft_id = reply_draft_id,
    reply_draft = reply_draft,
    reply_pending = reply_pending,
    toggle_group = function(key)
        toggle_key(expanded_groups, key)
    end,
    toggle_message = function(id)
        toggle_key(expanded_messages, tostring(id))
    end,
    set_reply_draft = set_reply_draft,
    clear_reply = clear_reply,
    send_reply = send_reply,
    panel_open = panel_open,
    panel_kind = panel_kind,
    panel_instance = panel_instance,
    open_panel = open_panel,
    toggle_panel = toggle_panel,
    close_panel = close_panel,
    set_media_hover = set_media_hover,
    bluetooth_codec_for = bluetooth_codec_for,
    audio_output_picker = audio_output_picker,
    audio_input_picker = audio_input_picker,
    updates_log_open = updates_log_open,
    hidden_draft = hidden_draft,
    hidden_ssid = hidden_ssid,
    credential_step = credential_step,
    hidden_join = hidden_join,
    open_hidden_prompt = open_hidden_prompt,
    clear_network_prompts = clear_network_prompts,
    cancel_network_join = cancel_network_join,
    panel_showing = panel_showing,
    panel_is = panel_is,
    active_modal = active_modal,
    modal_showing = modal_showing,
    toggle_modal = toggle_modal,
    close_modal = close_modal,
}
