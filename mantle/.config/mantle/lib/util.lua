-- Shared helpers without UI nodes.
local icons = require("config.icons")
local theme = require("config.theme")
local util = {}

local function try(read, value)
    if value ~= nil then
        return pcall(read, value)
    end
end

-- Unhydrated reads show "--"; failed reads show "!".
function util.label(signal, read)
    return signal:map(function(value)
        local ok, text = try(read, value)
        return ok == false and "!" or (ok and text) or "--"
    end)
end

--- `fn` mapped over a signal, or applied once to a plain value.
---@param value any
---@param fn fun(value: any): any
---@return any
function util.lift(value, fn)
    if type(value) == "userdata" then
        return value:map(fn)
    end
    return fn(value)
end

-- `yes` must be truthy, matching Lua's `on and yes or no` idiom.
function util.choose(value, yes, no)
    return util.lift(value, function(on) return on and yes or no end)
end

function util.find(items, predicate)
    for _, item in ipairs(items or {}) do
        if predicate(item) then
            return item
        end
    end
end

function util.chunk(items, size)
    local rows = {}
    for at = 1, #items, size do
        rows[#rows + 1] = { table.unpack(items, at, math.min(at + size - 1, #items)) }
    end
    return rows
end

--- Bold text runs for content that must carry its own weight.
---@param label string|Bound
---@return TextRun[]|Bound
function util.bold(label)
    return util.lift(label, function(shown)
        return { { text = shown, bold = true } }
    end)
end

---@param on Signal<boolean>
---@param label string
function util.bold_when(on, label)
    return on:map(function(enabled)
        return enabled and util.bold(label) or label
    end)
end

--- Copy both lists without the stack limit of `table.unpack`, reached by long install logs.
---@param first table|nil
---@param second table|nil
---@return table
function util.concat(first, second)
    first, second = first or {}, second or {}
    return table.move(second, 1, #second, #first + 1, table.move(first, 1, #first, 1, {}))
end

--- Copy-on-write triggers a push without mutating a value under an unfinished resolve.
function util.with(source, key, value)
    local copy = {}
    for name, held in pairs(type(source) == "table" and source or {}) do
        copy[name] = held
    end
    copy[key] = value
    return copy
end

function util.battery_is_draining(state)
    return state == "Discharging" or state == "Empty"
end

-- Shared percentages for the indicator, notifications and automatic suspend.
util.battery_thresholds = { low = 20, critical = 10, suspend = 8 }

-- Only draining batteries cross these thresholds, so 14% on the charger cannot turn red.
function util.battery_at_most(battery, percent)
    return battery ~= nil and battery.present and util.battery_is_draining(battery.state)
        and battery.percent <= percent
end

function util.battery_glyph(battery)
    if battery == nil or not battery.present then
        return icons.battery_ac
    end
    -- Charge-limited machines normally show the plug; a stopped charge gets the bolt.
    if battery.state == "PendingCharge" then
        return icons.battery_pending
    end
    if battery.state == "Charging" or battery.state == "FullyCharged" then
        return icons.battery_ac
    end
    local bucket = math.floor((battery.percent or 0) / 20) + 1
    return icons.battery_levels[math.max(1, math.min(5, bucket))]
end

-- Desktop IDs, toplevel app IDs and tray IDs vary in case; the index keys are folded.
function util.app_entry(applications, app_id)
    local by_app_id = applications and applications.by_app_id
    if by_app_id == nil or app_id == nil or app_id == "" then
        return nil
    end
    local index = by_app_id[app_id] or by_app_id[string.lower(app_id)]
    return index and applications.entries[index]
end

function util.app_icon(entry)
    return mantle.applications:map(function(applications)
        local app = util.app_entry(applications, entry.app_id)
        return (app and app.icon) or ""
    end)
end

-- The engine's `set_volume` clamp, in percent.
util.MAX_VOLUME = 150

-- Noon today: it changes once a day, so a reader re-resolves at midnight, not on each clock tick.
util.today = mantle.system:map(function(system)
    local now = os.date("*t", system and system.time)
    return os.time({ year = now.year, month = now.month, day = now.day, hour = 12 })
end)

-- Strip redundant ALSA description words.
function util.device_name(device)
    if device == nil then
        return nil
    end
    local name = device.name or ""
    name = name:gsub("%s*[Hh]igh [Dd]efinition [Aa]udio [Cc]ontroller", ""):gsub("%s*H?D? ?[Aa]udio [Cc]ontroller", "")
    name = name:gsub("%s*[Dd]igital [Ss]tereo", ""):gsub("%s*[Aa]nalog [Ss]tereo", "")
    name = name:gsub("%s*%(HDMI%)", " HDMI"):gsub("%s*%(S/PDIF%)", " S/PDIF"):gsub("%s*%(IEC958%)", " S/PDIF")
    name = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
    return name ~= "" and name or device.name
end

function util.active_device(devices)
    return util.find(devices, function(device) return device.active end)
end

-- `util.audio_device_glyph`'s hints, strongest first: `{ field, pattern, glyph, input glyph? }`.
local AUDIO_DEVICE_HINTS = {
    { "port",        "headset",     "headset" },
    { "port",        "headphones",  "headphones" },
    { "port",        "hdmi",        "television" },
    { "port",        "displayport", "television" },
    { "form_factor", "headset",     "headset" },
    { "form_factor", "hands%-free", "headset" },
    { "form_factor", "headphone",   "headphones", "headset" },
    { "form_factor", "tv",          "television" },
    { "form_factor", "webcam",      "webcam" },
    { "form_factor", "handset",     "phone" },
    { "bus",         "usb",         "usb" },
}

-- Glyph for an `AudioDevice`, or `nil` when nothing names one; callers supply the fallback.
function util.audio_device_glyph(device, is_input)
    for _, hint in ipairs(AUDIO_DEVICE_HINTS) do
        local value = device and device[hint[1]]
        if value and value:find(hint[2]) then
            return icons[is_input and hint[4] or hint[3]]
        end
    end
end

-- Takes the raw audio payload, not a signal; callers choose when to read it.
-- Font glyphs let the OSD tint the volume icon.
function util.volume_glyph(audio)
    if audio == nil or audio.volume == nil then
        return "--"
    elseif audio.muted then
        return icons.vol_muted
    end
    local percent = audio.volume
    if percent < 1 then
        return icons.vol_zero
    elseif percent < 33 then
        return icons.vol_low
    elseif percent < 66 then
        return icons.vol_mid
    end
    return icons.vol_high
end

function util.network_glyph(network)
    if network == nil then
        return icons.wifi_none
    end
    if network.ssid == "Ethernet" then
        return icons.ethernet
    end
    -- A dead radio and a live one joined to nothing are different pictures.
    if not network.networking_enabled or not network.wifi_enabled then
        return icons.wifi_off
    end
    if network.ssid == nil then
        return icons.wifi_none
    end
    return icons.wifi[util.signal_tier(network.strength)]
end

function util.signal_tier(strength)
    local percent = strength or 0
    return percent >= 95 and 4 or percent >= 80 and 3 or percent >= 50 and 2 or 1
end

-- Stabilize the engine's HashMap order by name, then MAC. "\0" separates tied names.
function util.sorted_devices(devices)
    local function key(device)
        return (device.name ~= "" and device.name:lower() or device.mac) .. "\0" .. device.mac
    end
    local out = table.move(devices or {}, 1, #(devices or {}), 1, {})
    table.sort(out, function(left, right)
        return key(left) < key(right)
    end)
    return out
end

---@param ap AccessPointInfo?
---@return string? # Short band label, or `nil` when there is no band to name.
---@return Color # The band's colour, or `FG`.
function util.band_of(ap)
    local number = ap and ap.band and ap.band:match("^[%d%.]+")
    if number == "6" then
        return "6G", theme.GREEN
    elseif number == "5" then
        return "5G", theme.ACCENT
    elseif number == "2.4" then
        return "2.4", theme.FG
    end
    return nil, theme.FG
end

-- Band metadata lives in the AP list; wired links have no entry.
---@param network NetworkState?
---@return AccessPointInfo? # The associated access point, or `nil`.
function util.active_access_point(network)
    return util.active_device(network and network.available_networks)
end

-- Centre-zone labels need content-sized nodes to stay centred between Fill sides.
-- ponytail: codepoints approximate width; replace when the engine can elide at a max width
-- while reporting a short string's own width.
function util.truncate(value, limit)
    local text = tostring(value or "")
    local count = utf8.len(text)
    if count == nil or count <= limit then
        return text
    end
    return text:sub(1, utf8.offset(text, limit + 1) - 1) .. "…"
end

-- Shared tooltip ownership: leaving one button must not clear another button's hover.
function util.track_hover(key, name)
    return function(is_hovered)
        if is_hovered then
            key:set(name)
        elseif key:get() == name then
            key:set("")
        end
    end
end

-- A picker of four colours: `on` picks the first pair, off the second; each pair is hovered, then resting.
function util.tint(on, hovered)
    return function(on_hot, on_rest, hot, rest)
        return computed({ on, hovered }, function(is_on, is_hot)
            if is_on then
                return is_hot and on_hot or on_rest
            end
            return is_hot and hot or rest
        end)
    end
end

-- Hold the last value across nil or empty-string pushes; default to an empty string until one arrives.
function util.hold(signal, initial)
    local last = initial == nil and "" or initial
    return signal:map(function(value)
        last = value ~= nil and value ~= "" and value or last
        return last
    end)
end

function util.shown_when(signal, predicate)
    return signal:map(function(value)
        local ok, shown = try(predicate, value)
        return ok and shown or false
    end)
end

-- Fit whole rows so the scrolling edge never cuts through one.
function util.fit_height(items, budget, spacing, height_of)
    local total = 0
    for index, item in ipairs(items) do
        local grown = total + (index > 1 and spacing or 0) + height_of(item)
        if grown > budget then
            break
        end
        total = grown
    end
    return total
end

-- Keep the surface mapped through its exit tween.
function util.linger(signal, ms)
    return computed({ signal, delay(signal, ms) }, function(now, was)
        -- Before its first change, delay can hold 0. Lua treats 0 as truthy, so compare with true.
        return now == true or was == true
    end)
end

-- Missing, failed or non-true reads leave the toggle off.
function util.read_bool(value, read)
    local ok, result = try(read, value)
    return ok == true and result == true
end

-- Whitespace off both ends. Parenthesised: `gsub` also returns its count.
function util.trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function util.thousands(formatted)
    local sign, digits, rest = formatted:match("^(%-?)(%d+)(.*)$")
    if not digits then
        return formatted
    end
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. grouped .. rest
end

function util.capture(command, args, done)
    local lines = {}
    return process.run(command, args, function(line, stream)
        if stream == "stdout" then lines[#lines + 1] = line end
    end, function(code) done(table.concat(lines), code) end)
end

-- No log, no retry. Decode the complete body only after a successful exit.
function util.fetch_json(url, on_done)
    util.capture("curl", { "-fsS", "--max-time", "5", url }, function(body, code)
        local decoded = code == 0 and json.decode(body) or nil
        on_done(type(decoded) == "table" and decoded or nil, code)
    end)
end

-- A table seed survives reloads. Nested auth prompts restore the saved layout on the last close.
local layout_restore = state("layout_restore", { saved = -1, count = 0 })

function util.auto_english_layout(capability)
    capability:on_change(function(current, previous)
        local now = current ~= nil and current.active
        local was = previous ~= nil and previous.active
        local held = layout_restore:get()
        local saved, count = held.saved, held.count
        if now and not was then
            if count == 0 then
                local keyboard = mantle.keyboard:get()
                local index = keyboard and keyboard.active_layout_index or 0
                saved = index > 0 and index or -1
                if index > 0 then
                    mantle.keyboard:switch_layout(0)
                end
            end
            count = count + 1
        elseif was and not now then
            count = math.max(0, count - 1)
            if count == 0 and saved >= 0 then
                mantle.keyboard:switch_layout(saved)
                saved = -1
            end
        else
            return
        end
        layout_restore:set({ saved = saved, count = count })
    end)
end

return util
