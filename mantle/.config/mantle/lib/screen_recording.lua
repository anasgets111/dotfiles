-- One `gpu-screen-recorder` on a region or a whole output, pausable, saved with a notification
-- offering to play it. `session_process` holds the child across reloads and `mantle.processes`
-- reports it, so no launch script, lock file or poll. The config owns the argv, file name, pause
-- arithmetic and notification.
local store = require("lib.store")
local util = require("lib.util")

local RECORDER = "screen-recorder"
-- `xdg-user-dir`'s own answer without `user-dirs.dirs`.
local FALLBACK_DIRECTORY = (os.getenv("HOME") or "") .. "/Videos"

-- `SIGINT` makes it write the container's index on the way out; the default `SIGTERM` would leave an
-- unplayable file. The Supervisor uses it too when the session ends under a live recording.
local recorder = session_process { name = RECORDER, stop_signal = "INT" }

-- The panel's three words are not the encoder's five levels.
local QUALITY = { low = "medium", medium = "high", high = "very_high" }

-- `default_output|default_input` is one argument: the recorder mixes both sources itself.
local AUDIO = {
    off = {},
    desktop = { "-a", "default_output", "-ac", "aac" },
    mic = { "-a", "default_output|default_input", "-ac", "aac" },
}

-- View facts the Supervisor cannot know, having been handed an argv: what the panel calls this
-- capture, and the file being written.
local capture_label = state("recorder_label", "")
local output_path = state("recorder_path", "")

-- Between asking for a capture and the recorder answering; `slurp` alone is a whole subprocess of
-- user interaction.
local starting = state("recorder_starting", false)

-- The `slurp` in flight, so `stop` has something to cancel. Not `state`: a handle is this
-- generation's, and an in-place reload re-requires this module and loses it.
local selecting = nil

-- A stop asked for while `starting`. `state`, because the press and the moment it can be obeyed are
-- not the same evaluation: `slurp` may exit with a good region after the kill, the Supervisor may not
-- have reported `running` yet, and a reload drops `selecting` while the child lives on.
local cancelled = state("recorder_cancelled", false)

-- Pause arithmetic, which no process reports: `paused_total` banks finished pauses and `paused_at`
-- stamps an open one, elapsed being the difference. Every stamp is `mantle.system.monotonic`,
-- including the start, since durations only compare within one origin. `state`, so they survive a
-- reload; a replaced Renderer resets them and its paused seconds count as recorded.
local paused_total = state("recorder_paused_total", 0)
local paused_at = state("recorder_paused_at", 0)
local began_at = state("recorder_began_at", 0)

local function monotonic_now()
    return (mantle.system:get() or {}).monotonic or 0
end

local recording = recorder.running:map(function(up)
    return up == true
end)
local paused = paused_at:map(function(at)
    return at > 0
end)

-- The default output: only the focused monitor carries `focused_workspace`.
local monitor = mantle.workspaces:map(function(workspaces)
    for _, out in ipairs((workspaces and workspaces.outputs) or {}) do
        if out.focused_workspace ~= nil then
            return out.name
        end
    end
    return ""
end)

-- A config has no XDG lookup, so ask the tool, once per session.
local directory = state("recorder_directory", "")
if directory:get() == "" then
    process.run("xdg-user-dir", { "VIDEOS" }, function(line)
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            directory:set(trimmed)
        end
    end, function()
        if directory:get() == "" then
            directory:set(FALLBACK_DIRECTORY)
        end
    end)
end

local function setting(key, fallback)
    local value = store.screen_recorder:get()
    if type(value) ~= "table" or value[key] == nil then
        return fallback
    end
    return value[key]
end

local function set_setting(key, value)
    store:set("screen_recorder", util.with(store.screen_recorder:get(), key, value))
end

local function format_elapsed(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds / 60) % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds % 60)
    end
    return string.format("%d:%02d", minutes, seconds % 60)
end

local function elapsed_of(now, began, banked, open_since)
    if began == nil or began <= 0 then
        return 0
    end
    local held = banked + (open_since > 0 and (now - open_since) or 0)
    return math.max(0, now - began - held)
end

local elapsed_text = computed(
    { mantle.system, began_at, paused_total, paused_at, recording },
    function(system, began, banked, open_since, up)
        return up and format_elapsed(elapsed_of((system and system.monotonic) or 0, began, banked, open_since)) or ""
    end
)

-- The file name is the launch time, so two captures in one session cannot collide, and the
-- extension follows the container the panel chose.
local function launch(capture_args, label)
    local container = setting("container", "mp4")
    local dir = directory:get() ~= "" and directory:get() or FALLBACK_DIRECTORY
    local path = string.format("%s/%s.%s", dir:gsub("/$", ""), os.date("%Y%m%d_%H%M%S"), container)

    local args = util.concat(capture_args, {
        "-o", path,
        "-q", QUALITY[setting("quality", "high")] or "very_high",
        -- `math.floor`: a rate round-tripped through JSON comes back a float, and `-f 60.0` is refused.
        "-f", tostring(math.floor(tonumber(setting("fps", 60)) or 60)),
    })
    args = util.concat(util.concat(args, AUDIO[setting("audio", "desktop")] or AUDIO.desktop),
        { "-cursor", "yes" })

    capture_label:set(label)
    output_path:set(path)
    paused_total:set(0)
    paused_at:set(0)
    began_at:set(monotonic_now())
    starting:set(true)
    recorder:start("gpu-screen-recorder", args)
end

-- `"selection"` puts `slurp` on screen first; its stdout is the region and a non-zero exit is the
-- user pressing Escape, which is a cancel rather than a failure.
local function start(mode)
    if recording:get() or starting:get() then
        return
    end
    if mode ~= "selection" then
        local output = monitor:get()
        if output == "" then
            return
        end
        launch({ "-w", output }, output)
        return
    end

    starting:set(true)
    local region = ""
    selecting = process.run("slurp", { "-f", "%wx%h+%x+%y" }, function(line, stream)
        if stream == "stdout" then
            region = region .. line
        end
    end, function(code)
        selecting = nil
        starting:set(false)
        local selected = region:match("^%s*(.-)%s*$")
        -- Before the exit status: a killed `slurp` may still have exited cleanly with a region.
        if cancelled:get() then
            cancelled:set(false)
            return
        end
        if code ~= 0 or selected == "" or recording:get() then
            return
        end
        -- `-w <WxH+X+Y>`: this version deprecates `-w region -region ...` and writes nothing for it.
        launch({ "-w", selected }, string.format("Region %s", selected:match("^[^+]*")))
    end)
end

local function stop()
    if recording:get() then
        recorder:signal("INT")
        return
    end
    -- Nothing is up yet, so record the refusal: the selection callback and the `running` edge read it.
    if starting:get() then
        cancelled:set(true)
        if selecting then
            selecting:kill()
        end
    end
end

-- One press, whatever is in flight; the indicator cannot see `starting`. Returns what the press did,
-- not the state after it, which still reads "starting" until `slurp`'s exit callback runs.
local function toggle()
    if recording:get() or starting:get() then
        local did = recording:get() and "stopped" or "cancelled"
        stop()
        return did
    end
    -- Clear a cancel nothing consumed, so a stale flag cannot eat this capture.
    cancelled:set(false)
    start("selection")
    return "starting"
end

-- `mantle call rec.toggle`: the same decision the indicator makes. The returned word names the
-- press, not the recording, which is all a terminal caller can be told synchronously.
action("rec.toggle", toggle)

-- `SIGUSR2` either way; which edge it was is this config's bookkeeping.
local function toggle_pause()
    if not recording:get() then
        return
    end
    recorder:signal("USR2")
    local open_since = paused_at:get()
    if open_since > 0 then
        paused_total:set(paused_total:get() + (monotonic_now() - open_since))
        paused_at:set(0)
    else
        paused_at:set(monotonic_now())
    end
end

-- Every end, not only a requested one: a recorder that died on its own still wrote a file. Exit zero
-- means the index was written and there is something to offer; anything else is a refusal that would
-- otherwise announce a missing file. `-A default=Play` arms the popup body and draws no second
-- button; `notify-send` blocks until the popup expires and prints the chosen key.
local function announce_saved(finished_at, began, exit_code)
    local path = output_path:get()
    if path == "" then
        return
    end
    local name = path:match("[^/]+$") or path

    if exit_code ~= nil and exit_code ~= 0 then
        process.run("notify-send", {
            "-a", "Screen Recorder",
            "-i", "media-record",
            "-u", "critical",
            "Recording failed",
            string.format("gpu-screen-recorder exited %d; see the shell's log", exit_code),
        }, function() end, function() end)
        return
    end

    local duration = format_elapsed(elapsed_of(finished_at, began, paused_total:get(), paused_at:get()))
    local chosen = ""
    process.run("notify-send", {
        "-a", "Screen Recorder",
        "-i", "media-record",
        "-t", "5000",
        "-e",
        "-A", "default=Play",
        "-A", "play=Play",
        "Recording saved",
        string.format("%s · %s", duration, name),
    }, function(line, stream)
        if stream == "stdout" then
            chosen = chosen .. line
        end
    end, function()
        local key = chosen:match("^%s*(.-)%s*$")
        if key == "default" or key == "play" then
            process.detach("xdg-open", { path })
        end
    end)
end

local function session_of(payload)
    return ((payload or {}).sessions or {})[RECORDER]
end

-- Both edges the Supervisor can report: it came up, or `start_error` says why it did not.
mantle.processes:on_change(function(current, previous)
    local was = session_of(previous)
    local now = session_of(current)
    if now == nil then
        return
    end
    if now.running then
        starting:set(false)
        -- The press arrived before there was a process to signal; this is the first moment there is.
        if cancelled:get() then
            cancelled:set(false)
            recorder:signal("INT")
        end
        return
    end
    -- The edge, not the field: `start_error` stays set until the next `start`, so a later push would
    -- read an old failure as this attempt's.
    if now.start_error ~= "" and now.start_error ~= ((was or {}).start_error or "") then
        starting:set(false)
        -- It never came up, so there is nothing left for a pending cancel to stop.
        cancelled:set(false)
    end
    if was ~= nil and was.running then
        announce_saved(monotonic_now(), began_at:get(), now.exit_code)
        paused_total:set(0)
        paused_at:set(0)
    end
end)

return {
    recording = recording,
    paused = paused,
    starting = starting,
    elapsed_text = elapsed_text,
    capture_label = capture_label,
    start_error = recorder.start_error,
    monitor = monitor,
    directory = directory,
    set_setting = set_setting,
    start = start,
    stop = stop,
    toggle = toggle,
    toggle_pause = toggle_pause,
    open_directory = function()
        local dir = directory:get()
        if dir ~= "" then
            process.detach("xdg-open", { dir })
        end
    end,
}
