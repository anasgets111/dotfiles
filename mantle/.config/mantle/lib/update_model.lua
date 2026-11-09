-- The update run as pure data: transitions, phase, look and copy. `lib/updates.lua` stores the run and
-- runs the effects.
local M = {}

-- Seconds without an `installing` push before a started install counts as never started.
M.WATCHDOG = 10

-- Pacman, polkit and curl output to plain words, strongest first: a mirror that failed before another
-- served the file must not outrank the real cause.
local FAILURE_PHRASES = {
    { "Authorization cancelled",                 "request dismissed" },
    { "Authorization refused",                   "not authorized" },
    { "Another package manager is running",      "unable to lock database" },
    { "Files conflict with another package",     "conflicting files" },
    { "Not enough disk space",                   "not enough free disk space",   "no space left" },
    { "A package failed its signature check",    "invalid or corrupted package", "signature from" },
    { "Couldn't download; check the connection", "failed retrieving",            "could not resolve host", "connection refused", "timed out" },
    { "Authentication failed",                   "authentication" },
}

-- pkexec exits 126 when its prompt is dismissed and 127 when no agent answers.
local EXIT_REASONS = { [126] = "Authorization cancelled", [127] = "No password prompt appeared" }

local function copy(run, changes)
    local new = {}
    for key, value in pairs(run) do new[key] = value end
    for key, value in pairs(changes) do new[key] = value end
    return new
end

local function capital(text)
    return (text:gsub("^%l", string.upper))
end

function M.strip_ansi(line)
    return (line:gsub("\27%[[%d;?]*%a", ""))
end

local function phrase(lines)
    local lowered = table.concat(lines, "\n"):lower()
    for _, entry in ipairs(FAILURE_PHRASES) do
        for index = 2, #entry do
            if lowered:find(entry[index], 1, true) then
                return entry[1]
            end
        end
    end
end

function M.plain(text)
    text = text or ""
    return phrase({ text }) or capital(text:match("[^\n]*"))
end

function M.plural(count, word)
    return string.format("%d %s%s", count, word, count == 1 and "" or "s")
end

function M.duration(seconds)
    seconds = math.max(seconds, 0)
    if seconds < 60 then
        return seconds .. " sec"
    end
    local minutes, rest = seconds // 60, seconds % 60
    return rest == 0 and (minutes .. " min") or string.format("%d min %d sec", minutes, rest)
end

function M.ago(at, now)
    local seconds = now - at
    if seconds < 60 then
        return "just now"
    elseif seconds < 3600 then
        return (seconds // 60) .. " min ago"
    elseif seconds < 86400 then
        return (seconds // 3600) .. " h ago"
    end
    return M.plural(seconds // 86400, "day") .. " ago"
end

local function manager(u)
    return capital((u and u.aur_helper) or "pacman")
end

-- Why the install failed, in plain words. Exit codes never reach the user.
function M.failure_reason(u)
    if u.install_error ~= nil then
        return "Couldn't start " .. manager(u):lower() .. ": " .. M.plain(u.install_error)
    elseif EXIT_REASONS[u.install_exit_code] then
        return EXIT_REASONS[u.install_exit_code]
    end
    local lines, error_line = {}, nil
    for index, line in ipairs(u.install_log or {}) do
        lines[index] = M.strip_ansi(line)
        error_line = lines[index]:match("^error: (.+)") or error_line
    end
    return phrase(lines) or (error_line and capital(error_line))
        or manager(u) .. (u.install_exit_code == nil and " was stopped before it finished" or " stopped with an error")
end

-- A failed tool's reason from its own output, read back to its `▶` marker.
function M.tool_reason(code, command, log)
    if code == 126 or code == 127 then
        return command[1] .. (code == 127 and " is not installed" or " couldn't be run")
    end
    local own, error_line, last = {}, nil, nil
    for index = #log, 1, -1 do
        local line = M.strip_ansi(log[index]):match("^%s*(.-)%s*$")
        if line:find("^▶ ") then
            break
        end
        own[#own + 1] = line
        error_line = error_line or (line:lower():find("error", 1, true) and line)
        last = last or (line ~= "" and line)
    end
    local raw = error_line or last
    return phrase(own) or (raw and capital(raw:gsub("^[Ee]rror:%s*", ""))) or "Stopped with an error"
end

-- A fresh run; it replaces the last, so `read` starts false. An install already running is adopted.
-- `expected` counts the packages: pacman without a tty prints no step counter (mantle#53).
function M.start(kind, plan, now, u)
    return {
        kind = kind,
        started_at = now,
        plan = plan,
        expected = kind == "system" and #((u and u.packages) or {}) or 0,
        stage = kind == "system" and "packages" or "tools",
        tool = kind == "tools" and 1 or nil,
        saw_installing = (u and u.installing) == true,
        prev_error = u and u.install_error,
        failures = {},
    }
end

local function finish(run, changes, now)
    local new = copy(run, changes)
    new.stage, new.tool, new.finished_at = nil, nil, now
    return new
end

-- An install push. Pushes coalesce and the capability has no run id, so the end is any of: the run
-- was seen and stopped, it finished after this start, a new error, or nothing at all for `WATCHDOG`.
function M.on_push(run, u, now)
    if run.stage ~= "packages" or u == nil then
        return nil
    elseif u.installing then
        return not run.saw_installing and copy(run, { saw_installing = true }) or nil
    end
    local ended = run.saw_installing or (u.install_finished_at or 0) >= run.started_at
        or u.install_error ~= run.prev_error
    if not ended and now - run.started_at < M.WATCHDOG then
        return nil
    elseif ended and u.install_error == nil and u.install_exit_code == 0 then
        return #run.plan > 0 and copy(run, { stage = "tools", tool = 1 }) or finish(run, {}, now)
    end
    -- A half-upgraded system is the wrong place to rebuild a toolchain against, so no tools run.
    local reason = (ended or u.install_error) and M.failure_reason(u) or (manager(u) .. " did not start")
    return finish(run, { reason = reason }, now)
end

-- `token` and `index` name the tool that exited, so a stale callback changes nothing. A `nil` code is a
-- signal or a reload's kill: the run ends there, counting only the tools it reached.
function M.tool_exit(run, token, index, code, reason, now)
    if run.stage ~= "tools" or run.started_at ~= token or run.tool ~= index then
        return nil
    end
    local failures = run.failures or {}
    if code ~= 0 then
        failures = { table.unpack(failures) }
        failures[#failures + 1] = { name = run.plan[index], reason = reason or "Stopped before it finished" }
    end
    if code ~= nil and index < #run.plan then
        return copy(run, { failures = failures, tool = index + 1 })
    end
    return finish(run, { failures = failures, plan = { table.unpack(run.plan, 1, index) } }, now)
end

function M.outcome(run)
    return run.reason and "failed" or (#(run.failures or {}) > 0 and "issues") or "done"
end

-- Newer truth replaces an unread result. A failed one clears only on a clean check after its own
-- recheck, so a check racing the failure does not read it.
function M.check_ended(run, u)
    if not run.finished_at or run.read then
        return nil
    end
    local outcome = M.outcome(run)
    if (outcome == "done" and #u.packages > 0)
        or (outcome == "failed" and run.rechecked and u.check_error == nil and #u.packages == 0) then
        return copy(run, { rechecked = true, read = true })
    end
    return not run.rechecked and copy(run, { rechecked = true }) or nil
end

function M.read(run)
    return run.finished_at and not run.read and copy(run, { read = true }) or nil
end

function M.phase(u, run)
    if u == nil then
        return "loading"
    elseif (run.started_at and not run.finished_at) or u.installing then
        return "running"
    end
    local unread = run.finished_at and not run.read
    if unread and M.outcome(run) ~= "done" then
        return M.outcome(run)
    elseif #u.packages > 0 then
        return "pending"
    elseif unread then
        return "done"
    elseif u.checking then
        return "checking"
    end
    return u.check_error and "check_failed" or "idle"
end

-- The panel view of each phase; the rest share `idle`.
M.VIEW = { running = "running", done = "result", issues = "result", failed = "result" }

-- One meter across packages and tools, indeterminate while pacman reports no steps.
function M.progress(u, run)
    local tools, packages = #(run.plan or {}), run.expected or 0
    if run.stage == "tools" then
        return { done = packages + run.tool - 1, total = packages + tools, count = run.tool .. " of " .. tools }
    end
    local steps, step = (u and u.install_total_steps) or 0, (u and u.install_current_step) or 0
    local count = steps > 0 and (step .. " of " .. steps) or ""
    return { done = math.max(step - 1, 0), total = (steps > 0 and steps or packages) + tools, count = count }
end

-- "Updated 12 packages and 5 of 7 developer tools", or nil when nothing ran or the install failed.
function M.summary(run)
    local parts, plan, failed = {}, #(run.plan or {}), #(run.failures or {})
    if run.reason then
        return nil
    elseif (run.expected or 0) > 0 then
        parts[#parts + 1] = M.plural(run.expected, "package")
    end
    if plan > 0 then
        parts[#parts + 1] = failed > 0 and string.format("%d of %d developer tools", plan - failed, plan)
            or M.plural(plan, "developer tool")
    end
    return #parts > 0 and ("Updated " .. table.concat(parts, " and ")) or nil
end

function M.took(run)
    return M.duration((run.finished_at or 0) - (run.started_at or 0))
end

-- The header, bar and toast copy. `ctx` is `{ now, pacnew, polkit, bytes }`; `glyph` keys `config/icons.lua`.
function M.look(phase, u, run, ctx)
    local look = { glyph = "up_to_date", tone = "dim", title = "Up to date", detail = "", warning = "" }
    local checked = u and u.last_successful_check
    if phase == "loading" then
        look.title = "Waiting for the updater"
    elseif phase == "running" then
        local count, package = M.progress(u, run).count, u.install_current_package or ""
        look.glyph, look.tone = "updating", "accent"
        look.title = run.stage == "tools" and ("Updating " .. run.plan[run.tool])
            or ctx.polkit and "Waiting for your password"
            or count ~= "" and package ~= "" and ("Installing " .. package)
            or "Updating " .. ((run.expected or 0) > 0 and M.plural(run.expected, "package") or "packages")
        look.detail = count ~= "" and count or ("Started " .. M.ago(run.started_at or ctx.now, ctx.now))
    elseif phase == "failed" then
        look.glyph, look.tone, look.title, look.detail = "update_err", "red", "Update failed", run.reason
    elseif phase == "issues" then
        look.glyph, look.tone = "warning", "peach"
        look.title = M.plural(#run.failures, "developer tool") .. " failed"
        look.detail = string.format("%d of %d developer tools updated", #run.plan - #run.failures, #run.plan)
    elseif phase == "done" then
        local summary = M.summary(run)
        look.glyph, look.tone = "check", "green"
        look.title = summary and "Update complete" or "Already up to date"
        look.detail = summary and (summary .. " in " .. M.took(run)) or ""
    elseif phase == "pending" then
        local size = 0
        for _, package in ipairs(u.packages) do
            size = size + (package.download_size or 0)
        end
        look.glyph, look.tone = u.checking and "checking" or "updates", "accent"
        look.title = M.plural(#u.packages, "update") .. " available"
        look.detail = u.checking and "Checking for updates…" or size > 0 and (ctx.bytes(size) .. " to download") or ""
        if u.check_error then
            look.warning = string.format("Couldn't refresh: %s. This list is from %s.", M.plain(u.check_error),
                checked and M.ago(checked, ctx.now) or "an earlier check")
        end
    elseif phase == "checking" then
        look.glyph, look.tone, look.title = "checking", "accent", "Checking for updates…"
        look.detail = checked and ("Last checked " .. M.ago(checked, ctx.now)) or ""
    elseif phase == "check_failed" then
        look.glyph, look.tone, look.title, look.warning = "update_err", "peach", "Couldn't check for updates",
            M.plain(u.check_error)
    else
        look.detail = checked and ("Checked " .. M.ago(checked, ctx.now)) or "Not checked yet"
    end
    if look.warning == "" and (phase == "idle" or phase == "pending") and u.aur_error then
        look.warning = "AUR not checked: " .. M.plain(u.aur_error)
            .. ". Check again, or leave AUR out under Include in updates."
        look.glyph = phase == "idle" and "warning" or look.glyph
    end
    if look.warning ~= "" and (look.tone == "accent" or look.tone == "dim") then
        look.tone = "peach"
    end
    -- A restart and unmerged files outrank a plain "Up to date" or "Update complete" title.
    local quiet = phase == "idle" or phase == "done"
    local reboot = u and u.reboot_required and phase ~= "running"
    look.extras = {}
    if (phase == "failed" or phase == "issues") and u and #u.packages > 0 then
        look.extras[1] = M.plural(#u.packages, "update") .. " available"
    end
    if reboot and quiet then
        look.glyph, look.tone, look.title = "power", "peach", "Restart to finish updating"
    elseif reboot then
        look.extras[#look.extras + 1] = "Restart required"
    end
    if ctx.pacnew > 0 and phase ~= "running" then
        local files = M.plural(ctx.pacnew, "config file") .. " to merge"
        if phase == "idle" and not reboot and look.warning == "" then
            look.glyph, look.tone, look.title = "warning", "peach", files
        else
            look.extras[#look.extras + 1] = files
        end
    end
    return look
end

return M
