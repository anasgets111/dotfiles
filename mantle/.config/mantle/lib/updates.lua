-- The update service around `mantle.updates`: persistence, toasts, the install run and the developer
-- tooling that follows it. `modules/bar/panels/update_panel.lua` owns the wording on screen and
-- `modules/bar/indicators/updates.lua` the bar glyph; neither runs anything.
local util = require("lib.util")
local store = require("lib.store")
local ui = require("lib.ui_state")
local dev_tools = require("config.dev_tools")

-- Hourly, since each check is a real `-Sy` against a mirror. Twice this is stale.
local CHECK_INTERVAL = 3600

-- The user has read the result. Close sets it, the next install clears it.
local dismissed = state("updates_result_dismissed", false)

-- The capability publishes only the finish; the click is the only known start.
local started_at = state("updates_install_started_at", 0)

-- Which `requires` binaries are on `PATH`, probed on the first push. Named state keeps the answer
-- across reloads.
local tools_present = state("updates_tools_present", {})

-- The running `config/dev_tools.lua` entry and its output, shown after `install_log`.
local dev_running = state("updates_dev_tool", "")
local dev_log = state("updates_dev_log", {})
-- `{ finished_at, failures }` once this run's tools finish. A table seed: named state keeps its type.
local dev_result = state("updates_dev_result", {})

local function packages(updates)
    return (updates and updates.packages) or {}
end

local function plural(count, word)
    return string.format("%d %s%s", count, word, count == 1 and "" or "s")
end

-- A spawn failure publishes only `install_error`, never `install_finished_at`.
local function install_ended(updates)
    return updates ~= nil and (updates.install_finished_at ~= nil or updates.install_error ~= nil)
end

-- A finished run's result is on screen. Tools after an install are part of its run.
local result_showing = computed({ mantle.updates, dismissed, dev_running, dev_result },
    function(updates, is_dismissed, tool, dev)
        return not is_dismissed and tool == "" and updates ~= nil and not updates.installing and
            (install_ended(updates) or dev.finished_at ~= nil)
    end)

-- Whether this run included packages. A tools-only run leaves the last install's count and log.
local function ran_packages(updates)
    return updates ~= nil and (updates.install_finished_at or 0) >= started_at:get()
end

-- With `aur = true`, installs run through the helper when one exists.
local function manager(updates)
    return updates.aur_helper or "pacman"
end

-- A manager killed by a signal publishes no exit code, which is a failure.
local function install_failed(updates)
    return install_ended(updates) and (updates.install_error ~= nil or updates.install_exit_code ~= 0)
end

-- Where the run is, strongest first; the panel's cards and the bar glyph both ask it by name. Tools
-- after an install are `running` too, since the manager has exited but the run has not. A failed
-- check with a stale list is `pending`: the list still shows.
local phase = computed({ mantle.updates, result_showing, dev_running }, function(updates, showing, tool)
    if updates == nil then
        return "loading"
    elseif updates.installing or tool ~= "" then
        return "running"
    elseif showing then
        return install_failed(updates) and "failed" or "done"
    elseif updates.checking then
        return "checking"
    elseif #packages(updates) > 0 then
        return "pending"
    end
    return updates.check_error ~= nil and "check_failed" or "empty"
end)

-- Absent means on, so a tool added to `config/dev_tools.lua` runs without a `state.json` edit.
local function tool_enabled(name)
    return (store.updates_dev_tools:get() or {})[name] ~= false
end

-- `name`'s place among the tools a run will start (ticked and present), and their count.
local function tool_step(name)
    local present = tools_present:get()
    local step, total = 0, 0
    for _, tool in ipairs(dev_tools) do
        if tool_enabled(tool.name) and present[tool.requires] then
            total = total + 1
            if tool.name == name then
                step = total
            end
        end
    end
    return step, total
end

local function any_tool_runnable()
    return select(2, tool_step()) > 0
end

local NOTIFICATION_ID = "8001"

-- Dismissing closes the card, which also ends a waiting `notify-send --wait`.
local function dismiss_notifications()
    local notifications = mantle.notifications:get()
    for _, notification in ipairs((notifications and notifications.feed) or {}) do
        if notification.app_name == "System Updates" then
            mantle.notifications:dismiss(notification.id)
        end
    end
end

-- Replaces any pending toast. The action listener is detached and calls back through `mantle call`,
-- since a `process.run` listener dies on reload.
local function toast(urgency, title, body, action)
    dismiss_notifications()
    local args = {
        "-u", urgency,
        "-a", "System Updates",
        "-i", "system-software-update",
        "--replace-id", NOTIFICATION_ID,
    }
    if not action then
        return process.detach("notify-send", util.concat(args, { title, body }))
    end
    process.detach("sh", util.concat({
        "-c", 'notify-send "$@" | grep -q run-updates && mantle call updates.install', "sh",
    }, util.concat(args, { "--wait", "-A", "run-updates=" .. action, title, body })))
end

-- ponytail: unbounded, unlike the Supervisor's 200-line tail. Cap it if a run ever prints thousands.
local function append_dev_log(line)
    dev_log:set(util.concat(dev_log:get(), { line }))
end

-- Stops at the first non-zero exit. A reload kills the child with `nil` and ends the chain.
local function run_commands(commands, index, done)
    local command = commands[index]
    if command == nil then
        return done(true)
    end
    process.run(command[1], { table.unpack(command, 2) }, append_dev_log, function(code)
        if code == nil then
            return dev_running:set("")
        elseif code ~= 0 then
            log.error("update:", table.concat(command, " "), "exited", code)
            return done(false)
        end
        run_commands(commands, index + 1, done)
    end)
end

local function report_run(updates, failures)
    if install_failed(updates) then
        return toast("critical", "Update failed", "The updates panel has " .. manager(updates) .. "'s output")
    end
    if #failures > 0 then
        return toast("critical", "Update finished with failures", table.concat(failures, ", "))
    end
    local count = ran_packages(updates) and updates.install_total_steps or 0
    local tools = any_tool_runnable() and " and developer tooling" or ""
    toast("normal", "Update complete", count > 0 and (plural(count, "package") .. tools .. " updated")
        or "Developer tooling updated")
end

-- Walks `config/dev_tools.lua`; the panel's `LOG_COLOURS` tints the markers it logs.
local function run_tools(index, failures)
    local tool = dev_tools[index]
    if tool == nil then
        dev_running:set("")
        dev_result:set({ finished_at = os.time(), failures = failures })
        return report_run(mantle.updates:get(), failures)
    end
    if not tool_enabled(tool.name) then
        return run_tools(index + 1, failures)
    end
    if not tools_present:get()[tool.requires] then
        append_dev_log(string.format("[SKIP] %s (%s not found)", tool.name, tool.requires))
        return run_tools(index + 1, failures)
    end
    dev_running:set(tool.name)
    append_dev_log("▶ " .. tool.name)
    run_commands(tool.run, 1, function(ok)
        append_dev_log((ok and "[ OK ] " or "[FAIL] ") .. tool.name)
        if not ok then
            failures[#failures + 1] = tool.name
        end
        run_tools(index + 1, failures)
    end)
end

local function start_dev_tools()
    dev_log:set({})
    run_tools(1, {})
end

-- A retry runs with no pending count: a partial failure can leave zero pending on a half-upgraded
-- system.
local function install()
    local updates = mantle.updates:get()
    if updates == nil or updates.installing or dev_running:get() ~= "" then
        return
    end
    local packages_pending = (updates.count or 0) > 0 or install_failed(updates)
    if not packages_pending and not any_tool_runnable() then
        return
    end
    dismiss_notifications()
    started_at:set(os.time())
    dismissed:set(false)
    dev_result:set({})
    ui.updates_log_open:set(false)
    if packages_pending then
        return mantle.updates:install()
    end
    start_dev_tools()
end
action("updates.install", install)

-- `rows`' first answer with a pattern in `lowered`, each row `{ answer, pattern... }`.
local function first_match(lowered, rows)
    for _, entry in ipairs(rows) do
        for index = 2, #entry do
            if lowered:find(entry[index]) then
                return entry[1]
            end
        end
    end
end

-- Pacman output to actionable wording, strongest first.
local FAILURE_PHRASES = {
    { "Could not download; check the connection", "failed retrieving",            "could not resolve host", "connection refused" },
    { "Not enough disk space",                    "not enough free disk space" },
    { "A package failed its signature check",     "invalid or corrupted package", "signature from" },
    { "Files conflict with another package",      "conflicting files" },
    { "Authentication failed",                    "authentication" },
}

-- Only asked once `install_failed(updates)`, so `updates` is set.
local function failure_reason(updates)
    for _, line in ipairs(updates.install_log or {}) do
        local reason = first_match(line:lower(), FAILURE_PHRASES)
        if reason then
            return reason
        end
    end
    if updates.install_error ~= nil then
        return "The updater could not be started"
    end
    if updates.install_exit_code == nil then
        return manager(updates) .. " was killed before it finished"
    end
    return string.format("%s exited with %d", manager(updates), updates.install_exit_code)
end

-- Updates stay dormant until configured. Seeding from `mantle.storage`'s first push lets a restart
-- within the hour skip the check and still show an answer.
mantle.storage:on_change(function(_, previous)
    if previous == nil then
        mantle.updates:configure({
            interval = CHECK_INTERVAL,
            checked_at = store.updates_checked_at:get(),
            packages = store.updates_packages:get(),
            aur = store.updates_aur:get(),
        })
    end
end)

-- On a completed check, remember its time and packages and announce what is new, comparing names
-- with the stored key so a restart does not repeat the same twelve packages.
local function announce_check(updates, previous)
    -- Compare with the store, not the previous push: the first post-restart push carries seeded
    -- time.
    if updates.last_successful_check and updates.last_successful_check ~= store.updates_checked_at:get() then
        store:set("updates_checked_at", updates.last_successful_check)
        store:set("updates_packages", updates.packages)
    end
    -- Every fifth consecutive failure: the bar's count is no longer the system's answer.
    local failures = updates.consecutive_check_failures or 0
    if failures > 0 and failures % 5 == 0 and previous ~= nil and (previous.consecutive_check_failures or 0) ~= failures then
        toast("critical", "Update check failed", updates.check_error or "")
    end
    -- Only the push that ends a check has a fresh list.
    if updates.checking or previous == nil or previous.checking ~= true then
        return
    end
    if (updates.count or 0) == 0 then
        if not result_showing:get() then
            dismiss_notifications()
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
    toast("normal", "Updates available", body, "Run updates")
end

mantle.updates:on_change(function(updates, previous)
    if previous == nil then
        -- One shell for every tool.
        local names = {}
        for _, tool in ipairs(dev_tools) do
            names[#names + 1] = tool.requires
        end
        local found = {}
        process.run("sh", { "-c", 'for n; do command -v "$n" >/dev/null && echo "$n"; done', "sh", table.unpack(names) },
            function(line)
                found[line] = true
            end, function()
                tools_present:set(found)
            end)
    end
    if updates == nil then
        return
    end
    announce_check(updates, previous)
    -- Keyed on the stamp moving: pushes coalesce, so an `installing` edge can be missed.
    if previous == nil or updates.installing or not install_ended(updates) then
        return
    end
    if updates.install_finished_at == previous.install_finished_at and updates.install_error == previous.install_error then
        return
    end
    -- `packages` is stale after any run, failed or not.
    mantle.updates:check()
    if install_failed(updates) then
        -- A half-upgraded system is the wrong place to rebuild a toolchain against.
        return report_run(updates, {})
    end
    start_dev_tools()
end)

return {
    CHECK_INTERVAL = CHECK_INTERVAL,
    dismissed = dismissed,
    started_at = started_at,
    tools_present = tools_present,
    dev_running = dev_running,
    dev_log = dev_log,
    dev_result = dev_result,
    packages = packages,
    plural = plural,
    result_showing = result_showing,
    phase = phase,
    ran_packages = ran_packages,
    install_failed = install_failed,
    tool_step = tool_step,
    any_tool_runnable = any_tool_runnable,
    dismiss_notifications = dismiss_notifications,
    install = install,
    first_match = first_match,
    failure_reason = failure_reason,
}
