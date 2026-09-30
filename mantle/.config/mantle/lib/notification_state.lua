-- Notification interaction state shared by history and popups.
local M = {}

local notifications = require("lib.notifications")
local util = require("lib.util")
local store = require("lib.store")
local idle = require("lib.idle")
local disclosure = require("lib.disclosure")

-- Key by id + timestamp so replaced content pops again. Dismiss also removes history.
M.popup_seen = state("notification_popup_seen", {})

function M.mark_popups_seen()
    local seen = {}
    for _, notification in ipairs((mantle.notifications:get() or {}).feed or {}) do
        seen[notifications.notification_key(notification)] = true
    end
    M.popup_seen:set(seen)
end

-- Derived signals have no on_change; blanking and store writes must sync quiet explicitly.
local function screencast(privacy, wanted)
    -- `~= false`: the store reads nil before its first push, and the default is on.
    return wanted ~= false and privacy ~= nil and #privacy.screencast_users > 0
end

M.sharing = computed({ mantle.privacy, store.notifications_dnd_while_sharing }, screencast)

local function notification_quiet(is_sharing)
    local lock = mantle.lock:get()
    return (is_sharing or idle.blanked:get() or (lock ~= nil and lock.active)) and true or false
end

function M.sync_notification_quiet()
    mantle.notifications:set_quiet(notification_quiet(M.sharing:get()))
end

mantle.privacy:on_change(M.sync_notification_quiet)
mantle.lock:on_change(M.sync_notification_quiet)

function M.set_dnd_while_sharing(on)
    store:set("notifications_dnd_while_sharing", on)
    -- `sharing:get()` is still the previous push. `on` is the value just written.
    mantle.notifications:set_quiet(notification_quiet(screencast(mantle.privacy:get(), on)))
end

-- Retire the popup while retaining its history entry.
function M.hide_popup(notification)
    M.popup_seen:set(util.with(M.popup_seen:get(), notifications.notification_key(notification), true))
end

-- Opening is the moment to prune: a day-old normal entry is noise by then.
function M.open_history()
    local now = os.time()
    for _, notification in ipairs((mantle.notifications:get() or {}).feed or {}) do
        if notifications.stale(notification, now) then
            mantle.notifications:dismiss(notification.id)
        end
    end
    M.mark_popups_seen()
end

-- Tables keep dynamic notification IDs from growing the signal registry.
M.expanded_groups = disclosure.state("notification_expanded_groups", {})
M.expanded_messages = disclosure.state("notification_expanded_messages", {})

-- One native field buffer; the ID keeps Send on A from sending B's draft.
M.reply_draft_id = state("notification_reply_draft_id", 0)
M.reply_draft = state("notification_reply_draft", "")

local function toggle_key(signal, key)
    signal:set(util.with(signal:get(), key, not signal:get()[key]))
end

-- Prune departed notifications without writing unchanged maps.
local function prune(signal, live)
    local kept, changed = {}, false
    for key, value in pairs(signal:get()) do
        if live[key] then
            kept[key] = value
        else
            changed = true
        end
    end
    if changed then
        signal:set(kept)
    end
end

mantle.notifications:on_change(function(inbox)
    local ids, keys, groups = {}, {}, {}
    for _, notification in ipairs((inbox and inbox.feed) or {}) do
        ids[tostring(notification.id)] = true
        keys[notifications.notification_key(notification)] = true
        groups[notifications.group_key(notification)] = true
    end
    prune(M.expanded_messages, ids)
    prune(M.popup_seen, keys)
    prune(M.expanded_groups, groups)
end)

function M.set_reply_draft(id, text)
    M.reply_draft_id:set(id)
    M.reply_draft:set(text or "")
end

function M.clear_reply(id)
    if M.reply_draft_id:get() == id then
        M.reply_draft_id:set(0)
        M.reply_draft:set("")
    end
end

-- Keep keyboard focus while a live notification has a draft, even after the pointer leaves.
M.reply_pending = computed({ M.reply_draft_id, M.reply_draft, mantle.notifications }, function(id, text, inbox)
    if id == 0 or text == "" then
        return false
    end
    return util.find(inbox and inbox.feed, function(notification) return notification.id == id end) ~= nil
end)

-- Empty is a no-op: `reply` removes the notification either way, losing the card and sending nothing.
function M.send_reply(id)
    local text = M.reply_draft:get()
    if M.reply_draft_id:get() ~= id or text == "" then
        return
    end
    mantle.notifications:reply(id, text)
    M.clear_reply(id)
end

function M.toggle_group(key)
    toggle_key(M.expanded_groups, key)
end

function M.toggle_message(id)
    toggle_key(M.expanded_messages, tostring(id))
end

return M
