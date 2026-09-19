-- The glyph says what the updater does; the ground says whether it wants attention.
--
-- Five overlapping states share an order: a check error beats a stale count and a later spinner.
-- First match wins.
--
-- Here colour carries the state.
--
-- Visible when a package manager exists. `mantle.updates.package_manager` answers it before the
-- first check.
--
-- Keep it visible when up to date so its idle click can re-check.
--
-- The click never installs. Install happens only from the panel, where the package list makes
-- that decision visible. The notification's action button is the one exception.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local update_panel = require("modules.bar.panels.update_panel")
local store = require("lib.store")

local SLOT = "updates"

-- The panel owns "I have read the result"; `state(...)` is name-keyed, so this is that same signal.
-- Without it the badge would stay red until the next install rather than until the user closes the
-- result.
local dismissed = state("updates_result_dismissed", false)

-- Updates stay dormant until configured; otherwise `state_of` remains `idle` and
-- `visible` hides the indicator. Configure here, not `shell.lua`, because this module needs the
-- answer. The cadence is `update_panel.CHECK_INTERVAL`, which also sets what counts as stale there.
--
-- Seed on `mantle.storage`'s first push, which carries the file `lib/store.lua` declared.
-- Persisted `checked_at` and its package list let a restart within the hour
-- skip the check and still show an answer; `previous == nil` seeds once per process.
mantle.storage:on_change(function(_, previous)
    if previous == nil then
        mantle.updates:invoke("configure", {
            interval = update_panel.CHECK_INTERVAL,
            checked_at = store.updates_checked_at:get(),
            packages = store.updates_packages:get(),
        })
    end
end)

-- On a completed check, remember its time and packages, and announce what is new. The install's
-- own outcome is reported by `panels/update_panel.lua`, which is the only file that knows when the
-- developer tooling behind it has finished too.
--
-- "New" compares package names with the stored announced key: restarts do not repeat the same
-- twelve packages, and upgraded packages drop out on the next check.
mantle.updates:on_change(function(u, previous)
    -- Compare with the store, not the previous push: the first post-restart push carries seeded
    -- time.
    if u.last_successful_check and u.last_successful_check ~= store.updates_checked_at:get() then
        store:set("updates_checked_at", u.last_successful_check)
        store:set("updates_packages", u.packages)
    end
    -- Every fifth consecutive failure: the count on the bar is no longer the system's answer, and
    -- only the panel says so.
    local failures = u.consecutive_check_failures or 0
    if failures > 0 and failures % 5 == 0 and previous ~= nil and (previous.consecutive_check_failures or 0) ~= failures then
        update_panel.toast("critical", "Update check failed", u.check_error or "")
    end
    if u.checking or previous == nil or previous.checking ~= true then
        -- Only the push that ends a check has a fresh list.
        return
    end
    if (u.count or 0) == 0 then
        if not update_panel.result_showing:get() then
            update_panel.dismiss_notifications()
        end
        store:set("updates_notified", "")
        return
    end
    local announced = store.updates_notified:get() or ""
    local names = {}
    for _, package in ipairs(u.packages) do
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
    local body = fresh == 1 and string.format("One new package can be upgraded (%d)", u.count)
        or string.format("%d new packages can be upgraded (%d)", fresh, u.count)
    update_panel.toast("normal", "Updates Available", body, "Run updates")
end)

-- The order: installing, then a failed run, then a failed check, then a running check, then a
-- count. A failed install owns the glyph until the result is read.
local function state_of(u, is_dismissed)
    if u == nil then
        return "idle"
    end
    if u.installing then
        return "installing"
    end
    if not is_dismissed and update_panel.install_failed(u) then
        return "install_failed"
    end
    if u.check_error and u.check_error ~= "" then
        return "error"
    end
    if u.checking then
        return "checking"
    end
    if (u.count or 0) > 0 then
        return "pending"
    end
    return "idle"
end

local status = computed({ mantle.updates, dismissed }, state_of)

local indicator = icon_button(status:map(function(s)
    if s == "installing" then
        return icons.updating
    elseif s == "error" or s == "install_failed" then
        return icons.update_err
    elseif s == "checking" then
        return icons.checking
    elseif s == "pending" then
        return icons.updates
    end
    return icons.up_to_date
end), nil, {
    -- Right-click always opens the panel: at idle it is otherwise unreachable, and with it the
    -- reboot badge, the last check time, and the empty state.
    on_button = function(rect, mouse_button)
        if mouse_button ~= "left" and mouse_button ~= "right" then
            return
        end
        -- Read at click time: this handler is registered once, while `status` changes.
        if mouse_button == "right" or state_of(mantle.updates:get(), dismissed:get()) ~= "idle" then
            ui_state.toggle_panel(update_panel.kind, rect)
            return
        end
        -- The Supervisor refuses `check` while one is running, so no guard is needed.
        mantle.updates:invoke("check")
    end,
    slot = SLOT,
    -- Accent while this indicator's panel is open.
    selected = ui_state.panel_showing(update_panel.kind),
    -- Hide when the Supervisor has no supported package manager; `package_manager` stays nil, and
    -- an indicator that can only report its own failure is worse than none.
    visible = mantle.updates:map(function(u)
        return u ~= nil and u.package_manager ~= nil
    end),
    foreground = status:map(function(s)
        if s == "error" or s == "install_failed" then
            return theme.RED
        end
        -- Dim while idle, accent while pending.
        return s == "idle" and theme.DIM or theme.ACCENT
    end),
})

-- The glyph and its colour leave five states sharing two grounds; the tooltip text names which.
local update_tooltip = tooltip({
    id = "updates_tooltip",
    slot = SLOT,
    children = {
        cell(computed({ mantle.updates, dismissed }, function(u, is_dismissed)
            if u == nil then
                return "--"
            end
            local current = state_of(u, is_dismissed)
            if current == "installing" then
                local package = u.install_current_package
                return (package ~= nil and package ~= "") and ("Installing " .. package) or "Installing"
            end
            if current == "install_failed" then
                return "Update failed, click for details"
            end
            if current == "error" then
                return "Check failed, click for details"
            end
            if current == "checking" then
                return "Checking for updates"
            end
            if current == "pending" then
                return u.count == 1 and "One package can be upgraded"
                    or string.format("%d packages can be upgraded", u.count)
            end
            return "Up to date, right-click for the updater"
        end), theme.FG, theme.font.sm),
    },
})

return { indicator = indicator, tooltip = update_tooltip }
