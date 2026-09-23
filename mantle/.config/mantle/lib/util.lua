-- Pure helpers with no nodes, kept out of `components/`.
local icons = require("config.icons")
local theme = require("config.theme")
local util = {}

-- `pcall(read, value)`, or `nil` for a `nil` payload, which `read` never sees.
local function try(read, value)
    if value ~= nil then
        return pcall(read, value)
    end
end

-- `nil` payload to "--" and a raising reader to "!", so each module needs one line for its readout.
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

--- The `TextRun` list a bold `cell` takes; `cell` has no `bold` property.
---@param label string|Bound
---@return TextRun[]|Bound
function util.bold(label)
    return util.lift(label, function(shown)
        return { { text = shown, bold = true } }
    end)
end

--- `label` bold while `on` holds, for a weight that follows a signal.
---@param on Signal<boolean>
---@param label string
function util.bold_when(on, label)
    return on:map(function(enabled)
        return enabled and util.bold(label) or label
    end)
end

--- A fresh list holding `first` then `second`. Every signal push needs a copy, and
--- `{table.unpack(t)}` is bounded by the Lua stack, which a long install log reaches.
---@param first table|nil
---@param second table|nil
---@return table
function util.concat(first, second)
    first, second = first or {}, second or {}
    return table.move(second, 1, #second, #first + 1, table.move(first, 1, #first, 1, {}))
end

--- A copy of `source` with `key` set to `value`. Copy-on-write: identity drives the push, and
--- mutating a held value under an unfinished resolve loses the change.
function util.with(source, key, value)
    local copy = {}
    for name, held in pairs(type(source) == "table" and source or {}) do
        copy[name] = held
    end
    copy[key] = value
    return copy
end

-- Words for `mantle.battery.state`'s UPower names; `Unknown` is the fallback. The pending phrases say only what UPower
-- observed: it reports `PendingCharge` at every plug-in, and its `ChargeEndThreshold` disagrees with
-- sysfs here, so neither state can claim a charge limit.
local BATTERY_PHRASES = {
    Charging = "charging",
    Discharging = "discharging",
    Empty = "empty",
    FullyCharged = "full",
    PendingCharge = "waiting to charge",
    PendingDischarge = "waiting to discharge",
}

function util.battery_phrase(state)
    return BATTERY_PHRASES[state] or "state unknown"
end

-- `", 2h 14m left"`, or `""`: UPower estimates one duration at a time and neither while learning the
-- rate, so an empty answer is ordinary in the first minute after a plug or a boot.
function util.battery_eta(battery)
    local seconds = battery.time_to_empty or battery.time_to_full
    if not seconds then
        return ""
    end
    local suffix = battery.time_to_empty and "left" or "to full"
    local hours, minutes = seconds // 3600, seconds % 3600 // 60
    return hours > 0 and string.format(", %dh %02dm %s", hours, minutes, suffix)
        or string.format(", %dm %s", minutes, suffix)
end

function util.battery_is_draining(state)
    return state == "Discharging" or state == "Empty"
end

-- Thresholds as whole numbers; one table keeps the pill, two notifications, and automatic suspend
-- in agreement.
util.battery_thresholds = { low = 20, critical = 10, suspend = 8 }

-- Whether `battery` drains at or under `percent`. Every threshold uses this gate, so 14% with the charger
-- in cannot turn red.
function util.battery_at_most(battery, percent)
    return battery ~= nil and battery.present and util.battery_is_draining(battery.state)
        and battery.percent <= percent
end

-- Five-level glyph plus the two cable states. Takes the raw payload, so a `nil` battery draws the AC
-- glyph rather than needing a branch at the caller.
function util.battery_glyph(battery)
    if battery == nil or not battery.present then
        return icons.battery_ac
    end
    -- Deliberately inverted: charging is the ordinary state on a machine with a charge limit, so it
    -- draws the plug and only a stopped charge gets the distinct bolt.
    if battery.state == "PendingCharge" then
        return icons.battery_pending
    end
    if battery.state == "Charging" or battery.state == "FullyCharged" then
        return icons.battery_ac
    end
    -- Five buckets over 0..100. Lua's 1-based indexing makes 100% bucket 5, not an out-of-range 6.
    local bucket = math.floor((battery.percent or 0) / 20) + 1
    return icons.battery_levels[math.max(1, math.min(5, bucket))]
end

-- An `app_id`'s entry, through `mantle.applications.by_app_id`'s index into `entries`. Callers
-- spell it as a desktop file id, a toplevel `app_id` or a StatusNotifierItem `Id`, so fold the
-- caller's spelling; the map's keys are already folded.
function util.app_entry(applications, app_id)
    local by_app_id = applications and applications.by_app_id
    if by_app_id == nil or app_id == nil or app_id == "" then
        return nil
    end
    local index = by_app_id[app_id] or by_app_id[string.lower(app_id)]
    return index and applications.entries[index]
end

-- The themed icon for `entry`'s `app_id`, or `""`.
function util.app_icon(entry)
    return computed({ mantle.applications, entry }, function(applications, current)
        local app = util.app_entry(applications, current.app_id)
        return (app and app.icon) or ""
    end)
end

-- The current entry of `list_of(signal)` whose `field` matches `built`'s, else `built`: key
-- reconciliation keeps an `itemfn` node, built from its first snapshot, while that entry changes.
function util.live_entry(signal, list_of, built, field)
    return signal:map(function(value)
        for _, candidate in ipairs(list_of(value)) do
            if candidate[field] == built[field] then
                return candidate
            end
        end
        return built
    end)
end

-- The engine's `set_volume` clamp.
util.MAX_VOLUME = 1.5

-- The `active` entry of `mantle.audio.sinks` or `sources`, or `nil`.
function util.active_device(devices)
    for _, device in ipairs(devices or {}) do
        if device.active then
            return device
        end
    end
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

-- Raw `mantle.audio`, not a signal, so callers choose their `nil` behavior. Nerd Font glyphs rather
-- than themed icons, which the OSD could not tint.
function util.volume_glyph(audio)
    if audio == nil or audio.volume == nil then
        return "--"
    elseif audio.muted then
        return icons.vol_muted
    end
    local percent = audio.volume * 100
    if percent < 1 then
        return icons.vol_zero
    elseif percent < 33 then
        return icons.vol_low
    elseif percent < 66 then
        return icons.vol_mid
    end
    return icons.vol_high
end

-- Four strength buckets over 0..100, shared by the bar indicator and the lock card's status row.
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

-- Four strength buckets, 1-indexed. The bars in the bar, the bars in the list, and the list's
-- order all read it.
function util.signal_tier(strength)
    local percent = strength or 0
    return percent >= 95 and 4 or percent >= 80 and 3 or percent >= 50 and 2 or 1
end

-- Bluetooth devices by shown name, then MAC: the Supervisor builds the lists from a `HashMap`, whose
-- order changes on any rebuild. `"\0"` sorts below every name character.
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

-- A band's short label and colour: "6G", "5G", "2.4". `nil` with `FG` covers ethernet and a band
-- nothing reported.
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
        return "2.4", theme.PEACH
    end
    return nil, theme.FG
end

-- The `available_networks` entry the link is on: `NetworkState` carries no band, so band-shaped
-- questions come back through the AP list. A wired link has no entry, so callers need no branch.
---@param network NetworkState?
---@return AccessPointInfo? # The associated access point, or `nil`.
function util.active_access_point(network)
    return util.active_device(network and network.available_networks)
end

-- A codepoint budget, the exception to `components/cell.lua`'s pixel-box rule: centre-zone modules
-- need content-sized nodes between two `Fill` sides, and bounding them pushed short labels off
-- centre. ponytail: codepoints are a ragged pixel width. Wants a `text.max_width` that measures and
-- elides while reporting the string's own width when it fits. That is a layout change, not config.
function util.truncate(value, limit)
    local text = tostring(value or "")
    local count = utf8.len(text)
    if count == nil or count <= limit then
        return text
    end
    return text:sub(1, utf8.offset(text, limit + 1) - 1) .. "..."
end

-- An `on_hover` that holds `name` in `key` while the pointer is on its button, else `""`: a row of
-- buttons sharing one tooltip passes `key` as the tooltip's `group`.
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

-- `signal`'s last non-empty string, so a card fading out after its key clears keeps its text and place.
function util.hold(signal)
    local last = ""
    return signal:map(function(value)
        last = value ~= "" and value or last
        return last
    end)
end

function util.shown_when(signal, predicate)
    return signal:map(function(value)
        local ok, shown = try(predicate, value)
        return ok and shown or false
    end)
end

-- The height of the longest run of `items` that fits `budget` whole, `spacing` apart, so a scrolling
-- list's edge falls between rows instead of through one.
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

-- True while the source is true and for `ms` after it drops, keeping the surface mapped through an
-- exit tween.
function util.linger(signal, ms)
    return computed({ signal, delay(signal, ms) }, function(now, was)
        -- `== true`, not `now or was`: before the first change `delay` holds the property's identity,
        -- `0`, which Lua calls truthy and a `visible` refuses.
        return now == true or was == true
    end)
end

-- `read(value)` as a strict boolean for a toggle: a nil payload, a throwing `read` or a non-`true`
-- answer all read as off.
function util.read_bool(value, read)
    local ok, result = try(read, value)
    return ok == true and result == true
end

-- Whitespace off both ends. Parenthesised: `gsub` also returns its count.
function util.trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Thousands separators into an already-formatted number. Reversed, because grouping runs from the
-- right: "1234" is "1,234", not "123,4".
function util.thousands(formatted)
    local sign, digits, rest = formatted:match("^(%-?)(%d+)(.*)$")
    if not digits then
        return formatted
    end
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. grouped .. rest
end

-- The layout to restore, `-1` for none, and how many capabilities are active.
local saved_layout, active_count = -1, 0

-- Layout 0 (English) while any `capability.active` holds, then the prior layout back.
function util.auto_english_layout(capability)
    capability:on_change(function(state, previous)
        local now = state ~= nil and state.active
        local was = previous ~= nil and previous.active
        if now and not was then
            if active_count == 0 then
                local keyboard = mantle.keyboard:get()
                local index = keyboard and keyboard.active_layout_index or 0
                saved_layout = index > 0 and index or -1
                if index > 0 then
                    mantle.keyboard:invoke("switch_layout", 0)
                end
            end
            active_count = active_count + 1
        elseif was and not now then
            active_count = math.max(0, active_count - 1)
            if active_count == 0 and saved_layout >= 0 then
                mantle.keyboard:invoke("switch_layout", saved_layout)
                saved_layout = -1
            end
        end
    end)
end

return util
