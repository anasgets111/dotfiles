-- The update service around `mantle.updates`: the run record and its effects, toasts and persistence.
-- `lib/update_model.lua` holds the rules; the panel and the bar glyph draw `view` and `look`.
local util = require("lib.util")
local store = require("lib.store")
local ui = require("lib.ui_state")
local disclosure = require("lib.disclosure")
local theme = require("config.theme")
local icons = require("config.icons")
local dev_tools = require("config.dev_tools")
local model = require("lib.update_model")

local KIND = "updates"
local APP = "System Updates"
-- Hourly, since each check is a real `-Sy` against a mirror.
local CHECK_INTERVAL = 3600
-- As many as the Supervisor's `install_log` tail.
local LOG_LINES = 200
local TONE = { dim = theme.DIM, accent = theme.ACCENT, green = theme.GREEN, peach = theme.PEACH, red = theme.RED }
local CHECK_FAILED = "Couldn't check for updates"

local panel_showing = ui.panel_showing(KIND)

-- The current or last run; see `lib/update_model.lua`.
local run = state("updates_run", {})
-- The developer tools' output, apart from `run` so a line does not rerun every map of it.
local tool_log = state("updates_tool_log", {})
-- `.pacnew` and `.pacsave` files waiting for a merge, found on disk: they outlive the run that made them.
local pacnew = state("updates_pacnew", {})
-- Which `requires` binaries are on `PATH`; named state keeps the last answer while a reload re-probes.
local tools_present = state("updates_tools_present", {})
local restart_asked = disclosure.state("updates_restart_asked", false)

local minute = mantle.clock:map(function(clock) return clock.time // 60 end, os.time() // 60)
local polkit = mantle.polkit:map(function(agent) return agent.active end, false)

local function look_of(phase, updates, current, at, files, agent)
    local look = model.look(phase, updates, current,
        { now = at * 60, pacnew = #files, polkit = agent, bytes = util.bytes })
    look.icon, look.color = icons[look.glyph], TONE[look.tone]
    return look
end

local phase = computed({ mantle.updates, run }, model.phase, "loading")
local look = computed({ phase, mantle.updates, run, minute, pacnew, polkit }, look_of,
    look_of("loading", nil, {}, 0, {}, false))

local function is_busy(updates, current)
    return updates.checking or model.phase(updates, current) == "running"
end
local busy = computed({ mantle.updates, run }, is_busy, true)

-- Pacman's output unless the run was tools only, then the tools'. yay colours even without a tty.
local log_lines = computed({ mantle.updates, run, tool_log }, function(updates, current, lines)
    local own = {}
    for index, line in ipairs(current.kind ~= "tools" and updates.install_log or {}) do
        own[index] = model.strip_ansi(line)
    end
    return util.concat(own, lines)
end, {})

-- Ticked (absent counts as ticked) and on `PATH`; with `only`, the tools it names, ticked or not.
local function runnable_names(flags, present, only)
    local names = {}
    for _, tool in ipairs(dev_tools) do
        if present[tool.requires] and (only and only[tool.name] or not only and flags[tool.name] ~= false) then
            names[#names + 1] = tool.name
        end
    end
    return names
end

local function dismiss_toasts(summary)
    local notifications = mantle.notifications:get()
    for _, notification in ipairs((notifications and notifications.feed) or {}) do
        if notification.app_name == APP and (summary == nil or notification.summary == summary) then
            mantle.notifications:dismiss(notification.id)
        end
    end
end

-- Each opens the panel; no toast starts work.
local ACTIONS = { review = "Review updates", details = "Show details", restart = "Restart…" }

-- One slot: replaces any earlier toast. Skipped while the panel is open, which already shows it.
local function toast(urgency, title, body, keys)
    if panel_showing:get() then
        return
    end
    dismiss_toasts()
    local updates = mantle.updates:get()
    if updates and updates.reboot_required and title ~= "Restart to finish updating" then
        body = body .. "\nRestart to finish updating."
    end
    local args = { "-u", urgency, "-a", APP, "-i", "system-software-update" }
    for _, key in ipairs(keys) do
        args[#args + 1], args[#args + 2] = "-A", key .. "=" .. ACTIONS[key]
    end
    process.detach("notify-send", util.concat(args, { title, body }))
end

local function append_log(line)
    local lines = util.concat(tool_log:get(), { model.strip_ansi(line) })
    if #lines > LOG_LINES then
        table.remove(lines, 1)
    end
    tool_log:set(lines)
end

local function collect(command, args, done)
    local found = {}
    process.run(command, args, function(line, stream)
        if stream == "stdout" then found[#found + 1] = line end
    end, function(code)
        if code ~= nil then done(found) end
    end)
end

-- ponytail: `/etc` only, where pacman's backup files live; unreadable directories are skipped.
local function scan_pacnew()
    collect("find", { "/etc", "(", "-name", "*.pacnew", "-o", "-name", "*.pacsave", ")" }, function(found)
        table.sort(found)
        pacnew:set(found)
    end)
end

local function probe_tools()
    local args = { "-c", 'for n; do command -v "$n" >/dev/null && echo "$n"; done', "sh" }
    for _, tool in ipairs(dev_tools) do
        args[#args + 1] = tool.requires
    end
    collect("sh", args, function(found)
        local present = {}
        for _, name in ipairs(found) do present[name] = true end
        tools_present:set(present)
    end)
end

-- A toast never carries the `.pacnew` count, so it need not wait for the rescan.
local function finished(current)
    scan_pacnew()
    probe_tools()
    local outcome, updates = model.outcome(current), mantle.updates:get()
    local look = look_of(outcome, updates, current, 0, {}, false)
    local restart = outcome == "done" and updates and updates.reboot_required
    toast(outcome == "failed" and "critical" or "normal", look.title, look.detail,
        restart and { "details", "restart" } or { "details" })
end

local advance

-- Stops at the first non-zero exit. `env` turns a command missing from `PATH` into exit 127, so
-- `nil` is a signal or a reload's kill.
local function run_commands(commands, index, done)
    local command = commands[index]
    if command == nil then
        return done(0)
    end
    process.run("env", util.concat({ "--" }, command), append_log, function(code)
        if code ~= 0 then
            return done(code, command)
        end
        run_commands(commands, index + 1, done)
    end)
end

-- ponytail: `process.run` dies with every reload, which ends the run at that tool. `session_process`
-- survives reloads but captures no output; needs one that does.
local function start_tool(current)
    local name = current.plan[current.tool]
    local tool = util.find(dev_tools, function(entry) return entry.name == name end)
    append_log("▶ " .. name)
    run_commands(tool and tool.run or {}, 1, function(code, command)
        local reason = code and code ~= 0 and model.tool_reason(code, command, tool_log:get()) or nil
        append_log((code == 0 and "[ OK ] " or "[FAIL] ") .. name)
        advance(model.tool_exit(run:get(), current.started_at, current.tool, code, reason, os.time()))
    end)
end

function advance(new)
    if new == nil then
        return
    end
    local old = run:get()
    run:set(new)
    -- `packages` is stale after any install, failed or not; the capability does not recheck.
    if old.stage == "packages" and new.stage ~= "packages" then
        mantle.updates:check()
    end
    if new.finished_at and not old.finished_at then
        finished(new)
    elseif new.stage == "tools" and (new.started_at ~= old.started_at or new.tool ~= old.tool) then
        start_tool(new)
    end
end

local function reconcile()
    advance(model.on_push(run:get(), mantle.updates:get(), os.time()))
end

local function begin(kind, names)
    local updates = mantle.updates:get()
    if updates == nil or is_busy(updates, run:get()) or (kind == "tools" and #names == 0) then
        return
    end
    tool_log:set({})
    dismiss_toasts()
    advance(model.start(kind, names, os.time(), updates))
    if kind == "system" then
        mantle.updates:install()
        timer(model.WATCHDOG * 1000, reconcile)
    end
end

-- Everything pending, then the ticked tools. A failed install reruns even with nothing pending.
local function install()
    local updates = mantle.updates:get()
    local names = runnable_names(store.updates_dev_tools:get(), tools_present:get())
    local system = updates and (#updates.packages > 0 or model.phase(updates, run:get()) == "failed")
    begin(system and "system" or "tools", names)
end
action("updates.install", install)

local function retry_tools()
    local only = {}
    for _, failure in ipairs(run:get().failures or {}) do
        only[failure.name] = true
    end
    begin("tools", runnable_names({}, tools_present:get(), only))
end

local function dismiss()
    advance(model.read(run:get()))
    ui.close_panel()
end

local function notification_action(notification, key)
    if notification.app_name ~= APP or ACTIONS[key] == nil then
        return false
    end
    mantle.notifications:dismiss(notification.id)
    ui.open_panel(KIND, hover_rect(KIND):get())
    -- After the open, which resets disclosures.
    restart_asked:set(key == "restart")
    return true
end

-- Opening rescans `.pacnew`, since a merge runs in a terminal the shell does not watch. Closing reads
-- a done or issues result after the exit tween, unless the panel opened again meanwhile.
panel_showing:on_change(function(showing)
    if showing then
        dismiss_toasts()
        return scan_pacnew()
    end
    timer(theme.animation_ms, function()
        local current = run:get()
        if not panel_showing:get() and model.outcome(current) ~= "failed" then
            advance(model.read(current))
        end
    end)
end)

-- Updates stay dormant until configured; the stored answer lets a restart within the hour skip the check.
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

-- Announces names not announced before, even across a restart.
local function announce(updates)
    local names = {}
    for index, package in ipairs(updates.packages) do
        names[index] = package.name
    end
    table.sort(names)
    local announced = "\n" .. store.updates_notified:get() .. "\n"
    store:set("updates_notified", table.concat(names, "\n"))
    -- Anchored on newlines: a bare `find` counts a new `python` as announced beside `python-pip`.
    local fresh = #util.filter(names, function(name) return not announced:find("\n" .. name .. "\n", 1, true) end)
    if #names == 0 then
        dismiss_toasts("Updates available")
    elseif fresh > 0 then
        toast("normal", "Updates available", fresh == #names and model.plural(fresh, "package")
            or string.format("%d new · %d in all", fresh, #names), { "review" })
    end
end

mantle.updates:on_change(function(updates, previous)
    if updates == nil then
        return
    end
    -- Compare with the store, not the previous push: the first push after a restart carries the seed.
    if updates.last_successful_check and updates.last_successful_check ~= store.updates_checked_at:get() then
        store:set("updates_checked_at", updates.last_successful_check)
        store:set("updates_packages", updates.packages)
    end
    local current = run:get()
    -- An install this evaluation did not start, after the Renderer lost `run`.
    if updates.installing and (current.started_at == nil or current.finished_at) then
        advance(model.start("system", {}, os.time(), updates))
    end
    reconcile()
    local failures = updates.consecutive_check_failures or 0
    if failures > 0 and failures % 5 == 0 and previous and previous.consecutive_check_failures ~= failures then
        toast("normal", CHECK_FAILED, model.plain(updates.check_error) .. " · "
            .. model.plural(failures, "failed check") .. " in a row", { "details" })
    end
    if previous and previous.checking and not updates.checking then
        if updates.check_error == nil then
            dismiss_toasts(CHECK_FAILED)
        end
        advance(model.check_ended(run:get(), updates))
        announce(updates)
    end
end)

-- A reload killed the last evaluation's tool, if one ran; pacman lives in the Supervisor.
probe_tools()
scan_pacnew()
local current = run:get()
advance(model.tool_exit(current, current.started_at, current.tool, nil, nil, os.time()))
reconcile()

return {
    KIND = KIND,
    CHECK_INTERVAL = CHECK_INTERVAL,
    run = run,
    pacnew = pacnew,
    tools_present = tools_present,
    restart_asked = restart_asked,
    phase = phase,
    view = phase:map(function(name) return model.VIEW[name] or "idle" end),
    look = look,
    busy = busy,
    progress = computed({ mantle.updates, run }, model.progress, model.progress(nil, {})),
    log_lines = log_lines,
    runnable_names = runnable_names,
    install = install,
    update_tools = function(names) begin("tools", names) end,
    retry_tools = retry_tools,
    dismiss = dismiss,
    notification_action = notification_action,
}
