local theme = require("config.theme")
local icons = require("config.icons")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local update_panel = require("modules.bar.panels.update_panel")
local store = require("lib.store")

local SLOT = "updates"

-- The panel owns "I have read the result"; `state(...)` is name-keyed, so this is that same signal.
local dismissed = state("updates_result_dismissed", false)

-- Updates stay dormant until configured, on the cadence `update_panel.CHECK_INTERVAL` also uses for
-- staleness. Seeding from `mantle.storage`'s first push lets a restart within the hour skip the
-- check and still show an answer.
mantle.storage:on_change(function(_, previous)
    if previous == nil then
        mantle.updates:invoke("configure", {
            interval = update_panel.CHECK_INTERVAL,
            checked_at = store.updates_checked_at:get(),
            packages = store.updates_packages:get(),
        })
    end
end)

-- On a completed check, remember its time and packages and announce what is new, comparing names
-- with the stored key so a restart does not repeat the same twelve packages. The install's own
-- outcome belongs to `panels/update_panel.lua`, which also knows when its tooling finished.
mantle.updates:on_change(function(updates, previous)
    -- Compare with the store, not the previous push: the first post-restart push carries seeded
    -- time.
    if updates.last_successful_check and updates.last_successful_check ~= store.updates_checked_at:get() then
        store:set("updates_checked_at", updates.last_successful_check)
        store:set("updates_packages", updates.packages)
    end
    -- Every fifth consecutive failure: the bar's count is no longer the system's answer.
    local failures = updates.consecutive_check_failures or 0
    if failures > 0 and failures % 5 == 0 and previous ~= nil and (previous.consecutive_check_failures or 0) ~= failures then
        update_panel.toast("critical", "Update check failed", updates.check_error or "")
    end
    -- Only the push that ends a check has a fresh list.
    if updates.checking or previous == nil or previous.checking ~= true then
        return
    end
    if (updates.count or 0) == 0 then
        if not update_panel.result_showing:get() then
            update_panel.dismiss_notifications()
        end
        store:set("updates_notified", "")
        return
    end
    local announced = store.updates_notified:get()
    local names = {}
    for _, package in ipairs(updates.packages) do
        names[#names + 1] = package.name
    end
    table.sort(names)
    local key = table.concat(names, "\n")
    if key == announced then
        return
    end
    store:set("updates_notified", key)
    local fresh = 0
    for _, name in ipairs(names) do
        -- Anchored on newlines: a bare `find` matches inside a neighbour, so a new `python`
        -- counted as already announced whenever `python-pip` was in the stored list.
        if not ("\n" .. announced .. "\n"):find("\n" .. name .. "\n", 1, true) then
            fresh = fresh + 1
        end
    end
    if fresh == 0 then
        return
    end
    local body = fresh == 1 and string.format("One new package can be upgraded (%d)", updates.count)
        or string.format("%d new packages can be upgraded (%d)", fresh, updates.count)
    update_panel.toast("normal", "Updates Available", body, "Run updates")
end)

-- In order: installing, a failed run, a failed check, a running check, then a count. A failed
-- install owns the glyph until the result is read.
local function state_of(updates, is_dismissed)
    if updates == nil then
        return "idle"
    elseif updates.installing then
        return "installing"
    elseif not is_dismissed and update_panel.install_failed(updates) then
        return "install_failed"
    elseif updates.check_error and updates.check_error ~= "" then
        return "error"
    elseif updates.checking then
        return "checking"
    elseif (updates.count or 0) > 0 then
        return "pending"
    end
    return "idle"
end

local status = computed({ mantle.updates, dismissed }, state_of)

-- Glyph, colour and tooltip per state; the glyph and colour leave five states sharing two grounds,
-- so the tooltip names which. `pending`'s text carries the count, so it is built below.
local LOOKS = {
    installing = { icons.updating, theme.ACCENT, "Updating system and developer tooling..." },
    install_failed = { icons.update_err, theme.RED, "Update failed - click for details" },
    error = { icons.update_err, theme.RED, "Update failed - click for details" },
    checking = { icons.checking, theme.ACCENT, "Checking for updates…" },
    pending = { icons.updates, theme.ACCENT },
    idle = { icons.up_to_date, theme.DIM, "No system package updates - right-click for updater" },
}

local indicator = icon_button(status:map(function(current)
    return LOOKS[current][1]
end), nil, {
    -- Right-click always opens the panel: at idle it is otherwise unreachable, and with it the
    -- reboot badge, the last check time, and the empty state.
    on_button = function(rect, mouse_button)
        if mouse_button ~= "left" and mouse_button ~= "right" then
            return
        end
        if mouse_button == "right" or status:get() ~= "idle" then
            ui_state.toggle_panel(update_panel.kind, rect)
            return
        end
        -- The Supervisor refuses `check` while one is running, so no guard is needed.
        mantle.updates:invoke("check")
    end,
    slot = SLOT,
    selected = ui_state.panel_showing(update_panel.kind),
    -- No supported package manager leaves `package_manager` nil; an indicator that can only report
    -- its own failure is worse than none.
    visible = mantle.updates:map(function(updates)
        return updates ~= nil and updates.package_manager ~= nil
    end),
    foreground = status:map(function(current)
        return LOOKS[current][2]
    end),
})

local update_tooltip = tooltip({
    id = "updates_tooltip",
    slot = SLOT,
    text = computed({ mantle.updates, status }, function(updates, current)
        if updates == nil then
            return "--"
        elseif current == "pending" then
            return updates.count == 1 and "One package can be upgraded"
                or string.format("%d packages can be upgraded", updates.count)
        end
        return LOOKS[current][3]
    end),
})

return { indicator = indicator, tooltip = update_tooltip }
