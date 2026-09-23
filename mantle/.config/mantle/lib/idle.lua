-- Idle-seat policy, not execution: settings, the three stages, and what holds the session awake.
-- `modules/global/idle.lua` runs the clock, stamps each arming and fires. Side-effect-free, so bar
-- readers can require it; `modules/` requires `lib/`, never the reverse.
--
-- One one-second threshold counted on `mantle.system.monotonic`, not one per stage: the panel's
-- "idle 0:42" readout needs the tick anyway, and a stage arms when its predecessor reports `done`
-- rather than at a fixed second. If those pushes stop, stages stop too.
--
-- Any hold -- ours, a player's `org.freedesktop.ScreenSaver`, `systemd-inhibit --what=idle` --
-- withholds every threshold event, so stages need no guard of their own.
--
-- ponytail: the threshold reports idle one second after the last input, which `idle_since` subtracts
-- back out; `ext-idle-notifier-v1` has no "how long idle" call to do better.
local store = require("lib.store")
local util = require("lib.util")
local icons = require("config.icons")

local idle = {}

-- One registration; this threshold handles both display wake and counting.
idle.TICK = 1

-- Panel order, not run order, which follows the timeouts. `options` is in seconds.
idle.STAGES = {
    {
        key = "dpms",
        title = "Turn off displays",
        detail = "Until input comes back",
        icon = icons.display,
        options = { 30, 60, 120, 300, 600, 900 },
        -- The stage after this one waits for it.
        done = function()
            return idle.blanked:get()
        end,
    },
    {
        key = "lock",
        title = "Lock screen",
        detail = "Needs your password to come back",
        icon = icons.lock,
        options = { 30, 60, 120, 300, 600, 900, 1800 },
        -- Unlocking makes it false and disarms every following stage.
        done = function()
            local lock = mantle.lock:get()
            return lock ~= nil and lock.active
        end,
    },
    {
        key = "suspend",
        title = "Suspend",
        detail = "Sleeps the machine",
        icon = icons.sleep,
        options = { 300, 600, 900, 1800, 3600, 7200 },
        -- Terminal: nothing waits behind it, and a suspended machine is not idle. A stage without
        -- `done` never satisfies a successor.
    },
}

--- Stage by key, or `nil`; used to validate an `order` entry read from disk.
--- @param key string
--- @return table?
function idle.stage(key)
    for _, stage in ipairs(idle.STAGES) do
        if stage.key == key then
            return stage
        end
    end
end

-- Profile fallbacks; `idle.read` spells out the shared keys' own.
local DEFAULTS = {
    ac = { dpms_on = true, dpms_sec = 300, lock_on = true, lock_sec = 600, suspend_on = false, suspend_sec = 1800 },
    battery = { dpms_on = true, dpms_sec = 120, lock_on = true, lock_sec = 180, suspend_on = true, suspend_sec = 600 },
}

-- Each stage exactly once: drop unknown and duplicate names, append missing ones in declaration
-- order. Repairs a hand-edited `state.json` and files predating a new stage.
local function resolve_order(stored)
    local seen, out = {}, {}
    for _, key in ipairs(type(stored) == "table" and stored or {}) do
        if type(key) == "string" and not seen[key] and idle.stage(key) then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    for _, stage in ipairs(idle.STAGES) do
        if not seen[stage.key] then
            out[#out + 1] = stage.key
        end
    end
    return out
end

--- Fill every missing key: `persistent_table` seeds only the top-level `idle`, so an older
--- `state.json` can be missing a stage timeout.
--- @param stored table? `store.idle`'s payload
--- @return table
function idle.read(stored)
    stored = type(stored) == "table" and stored or {}
    ---@type table<string, any>
    local out = {
        enabled = stored.enabled == true,
        privacy_auto_inhibit = stored.privacy_auto_inhibit ~= false,
        order = resolve_order(stored.order),
    }
    for name, fallback in pairs(DEFAULTS) do
        local held = type(stored[name]) == "table" and stored[name] or {}
        local profile = {}
        for key, default in pairs(fallback) do
            local value = held[key]
            if type(value) ~= type(default) then
                value = default
            end
            profile[key] = value
        end
        out[name] = profile
    end
    return out
end

--- Write one setting to `lib/store.lua`; `profile` is `"ac"`, `"battery"`, or `nil` for shared
--- keys.
--- @param profile string?
--- @param key string
--- @param value any
function idle.write(profile, key, value)
    local current = idle.read(store.idle:get())
    if profile == nil then
        store:set("idle", util.with(current, key, value))
        return
    end
    store:set("idle", util.with(current, profile, util.with(current[profile], key, value)))
end

--- Next `stage.options` value from `sec`, wrapping; `step = -1` goes down. Wraps rather than stops,
--- like the power menu's brightness: stopping at an end reads as broken.
--- @param stage table one entry of `idle.STAGES`
--- @param sec integer
--- @param step integer
--- @return integer
function idle.cycle(stage, sec, step)
    local options = stage.options
    -- Nearest option at or above the stored value, so a hand-edited 45s steps to 60s.
    local index = #options
    for position, value in ipairs(options) do
        if value >= sec then
            index = position
            break
        end
    end
    if options[index] ~= sec then
        -- Land on that neighbour first; an off-list value is one press from a listed value.
        return step > 0 and options[index] or options[math.max(1, index - 1)]
    end
    return options[(index - 1 + step) % #options + 1]
end

--- Timeout words: `"Off"`, `"45s"`, `"5m"`, `"1m 30s"`.
--- @param sec integer?
--- @return string
function idle.format(sec)
    if sec == nil or sec <= 0 then
        return "Off"
    end
    if sec < 60 then
        return string.format("%ds", sec)
    end
    if sec % 60 == 0 then
        return string.format("%dm", sec // 60)
    end
    return string.format("%dm %ds", sec // 60, sec % 60)
end

--- Clock duration for the two counters: `"0:42"`, `"14:03"`.
--- @param sec integer
--- @return string
function idle.clock(sec)
    return string.format("%d:%02d", math.max(0, sec) // 60, math.max(0, sec) % 60)
end

-- Named `state()` throughout: registry entries survive a reload, so an edit cannot forget a manual
-- hold or leak its inhibitor.

--- The `mantle.system.monotonic` reading when the seat went idle, or `0` while awake. It and the
--- clock's epoch survive a reload together, and a Supervisor restart rebuilds both.
idle.since = state("idle_since", 0)

--- Arming time in `mantle.system.monotonic`, keyed by `stage.key`. Missing means not armed; the
--- stamp makes delay relative, and clearing it makes unlock undo the sequence.
idle.armed_at = state("idle_armed_at", {})

--- Which profile [`idle.armed_at`]'s stamp was taken under, so `modules/global/idle.lua` can
--- re-stamp on a switch instead of measuring one profile's timeout against the other's stamp.
idle.armed_profile = state("idle_armed_profile", "")

--- Whether the displays are off because `modules/global/idle.lua` turned them off.
idle.blanked = state("idle_blanked", false)

--- The arming stamp each stage has fired for. `dpms` and `lock` report `done` and the walk moves
--- past them; terminal `suspend` observes nothing, and without this re-ran every tick.
idle.fired_at = state("idle_fired_at", {})

--- The bar button's own hold.
idle.manual = state("idle_manual", false)

--- Whether a logind inhibitor is out in our name. Not derived from [`idle.reasons`]: the calls are
--- counted, and a wrong count leaks one.
idle.holding = state("idle_holding", false)

--- @param power table? `mantle.power`'s payload
--- @return string `"ac"` or `"battery"`
function idle.profile_of(power)
    return (power ~= nil and power.on_battery == true) and "battery" or "ac"
end

--- Which profile's numbers are in force. No UPower means AC: a machine that cannot say it is on
--- battery is plugged in.
idle.active_profile = mantle.power:map(idle.profile_of)

local PRIVACY_REASONS = { { "camera_users", "camera" }, { "microphone_users", "microphone" },
    { "screencast_users", "screen capture" } }

--- Reasons *this config* would take a logind hold for. Pure and payload-based, so
--- `modules/global/idle.lua` can pass `on_change`'s value rather than read a stale `computed`.
---
--- Foreign holders are absent on purpose: holding because someone else holds is a second block for
--- one reason that nothing releases. [`idle.reasons`] adds them back. Playback is not read here --
--- a player that wants the screen up says so itself, and the engine honours it.
--- @param privacy table? `mantle.privacy`'s payload
--- @param settings table the result of [`idle.read`]
--- @param manual boolean
--- @return string[]
function idle.own_reasons(privacy, settings, manual)
    local reasons = {}
    if manual then
        reasons[#reasons + 1] = "manual"
    end
    -- Named separately, so "why is my laptop not sleeping" gets the real reason. No application
    -- declares these, which is why they are ours. Gated on the master switch, unlike the explicit
    -- `manual` press: with automatic actions off there are no stages to hold off.
    if settings.enabled and settings.privacy_auto_inhibit then
        for _, source in ipairs(PRIVACY_REASONS) do
            if #((privacy or {})[source[1]] or {}) > 0 then
                reasons[#reasons + 1] = source[2]
            end
        end
    end
    return reasons
end

--- Everything holding the session awake, ours and anyone else's, for whatever draws the list.
idle.reasons = computed({ mantle.privacy, store.idle, idle.manual, mantle.idle },
    function(privacy, stored, manual, foreign)
        local reasons = idle.own_reasons(privacy, idle.read(stored), manual)
        for _, inhibitor in ipairs((foreign or {}).inhibitors or {}) do
            -- `who` is empty through xdg-desktop-portal, so `why` ("Playing video") is the only label.
            reasons[#reasons + 1] = inhibitor.who ~= "" and inhibitor.who
                or inhibitor.why ~= "" and inhibitor.why
                or "another application"
        end
        return reasons
    end)

--- Sentence naming the holders. `inhibited` outruns [`idle.reasons`] -- our own hold is excluded
--- from `mantle.idle.inhibitors` and a surface inhibitor names nothing -- which left an empty list.
--- @param reasons string[]
--- @param inhibited boolean
--- @return string
function idle.held_text(reasons, inhibited)
    if #reasons > 0 then
        -- A list, not a sentence: a holder's own `why` is a clause, and reads as one after a colon.
        return "Held awake by: " .. table.concat(reasons, ", ")
    end
    return inhibited and "Held awake by something that did not name itself" or "Nothing is holding this awake"
end

--- Anything holding the session awake, unnamed holders included: `inhibited` is the authoritative
--- `BlockInhibited` gate, so an unreadable `who` still stops the countdown.
idle.inhibited = computed({ idle.reasons, mantle.idle }, function(reasons, foreign)
    return #reasons > 0 or (foreign ~= nil and foreign.inhibited == true)
end)

--- Make the logind hold match the reasons. One writer, called by everything that can change the
--- answer; three callers counting take/drop themselves would disagree.
function idle.sync_inhibit()
    -- Our hold is excluded from `mantle.idle.inhibitors`, so readback cannot mistake it for a foreign
    -- one and skip acquiring.
    local reasons = idle.own_reasons(mantle.privacy:get(), idle.read(store.idle:get()), idle.manual:get())
    local want = #reasons > 0
    if want == idle.holding:get() then
        return
    end
    idle.holding:set(want)
    if want then
        mantle.idle:inhibit(table.concat(reasons, " + "))
    else
        mantle.idle:release_inhibit()
    end
end

--- Flip the bar button's hold and settle its inhibitor.
--- @param on boolean
function idle.set_manual(on)
    idle.manual:set(on)
    idle.sync_inhibit()
end

--- Runnable stages in order with their post-arming delays. `at` is a display total; a stage's clock
--- starts when it arms.
--- @param settings table the result of [`idle.read`]
--- @param profile string `"ac"` or `"battery"`
--- @return { list: table[], total: integer }
function idle.plan(settings, profile)
    local numbers = settings[profile]
    local list = {}
    local from = 0
    for _, key in ipairs(settings.order) do
        local stage = idle.stage(key)
        local delay = stage and numbers[key .. "_sec"] or 0
        if stage and numbers[key .. "_on"] and delay > 0 then
            from = from + delay
            list[#list + 1] = { key = key, icon = stage.icon, title = stage.title, at = from, delay = delay }
        end
    end
    return { list = list, total = from }
end

--- Currently armed stage from `plan`, or `nil`: the first one not yet [`done`](idle.STAGES). A stage
--- without `done` ends the chain. Recomputed every tick, so an unlock disarms the rest by itself.
--- @param plan table the result of [`idle.plan`]
--- @return table? one entry of `plan.list`
function idle.armed(plan)
    for _, entry in ipairs(plan.list) do
        local stage = idle.stage(entry.key)
        if not (stage and stage.done and stage.done() == true) then
            return entry
        end
    end
end

--- Move one stage `step` places. Out-of-range is a no-op, so the modal can wire both chevrons.
--- @param key string
--- @param step integer `-1` earlier, `1` later
function idle.move(key, step)
    local order = idle.read(store.idle:get()).order
    local at
    for index, name in ipairs(order) do
        if name == key then
            at = index
        end
    end
    local to = at and at + step
    if to == nil or to < 1 or to > #order then
        return
    end
    order[at], order[to] = order[to], order[at]
    idle.write(nil, "order", order)
end

--- The master switch on its own, for anything drawing "is automation running".
idle.enabled = store.idle:map(function(stored)
    return idle.read(stored).enabled
end)

idle.schedule = computed({ store.idle, idle.active_profile }, function(stored, profile)
    return idle.plan(idle.read(stored), profile)
end)

--- Armed stage and elapsed time from the stamp `modules/global/idle.lua` writes. No stage is
--- `{ key = "", elapsed = 0 }`.
idle.arming = computed({ mantle.system, idle.armed_at }, function(system, stamps)
    for key, at in pairs(stamps or {}) do
        return { key = key, elapsed = math.max(0, ((system and system.monotonic) or 0) - at) }
    end
    return { key = "", elapsed = 0 }
end)

--- Seat idle duration in seconds, or `0` while awake.
idle.elapsed = computed({ mantle.system, idle.since }, function(system, since)
    if since == 0 then
        return 0
    end
    return math.max(0, ((system and system.monotonic) or 0) - since)
end)

return idle
