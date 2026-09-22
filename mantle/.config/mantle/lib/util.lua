-- Pure helpers with no nodes, kept out of `components/`.
local util = {}

-- `nil` payload to "--" and a raising reader to "!", so each module needs one line for its readout.
function util.label(signal, read)
    return signal:map(function(value)
        if value == nil then
            return "--"
        end
        local ok, text = pcall(read, value)
        if not ok then
            return "!"
        end
        return text or "--"
    end)
end

--- The `TextRun` list a bold `cell` takes; `cell` has no `bold` property.
---@param label string|Bound
---@return TextRun[]|Bound
function util.bold(label)
    if type(label) == "string" then
        return { { text = label, bold = true } }
    end
    ---@cast label Signal
    return label:map(function(shown)
        return { { text = shown, bold = true } }
    end)
end

--- A fresh list holding `first` then `second`. Every signal push needs a copy, and
--- `{table.unpack(t)}` is bounded by the Lua stack, which a long install log reaches.
---@param first table|nil
---@param second table|nil
---@return table
function util.concat(first, second)
    local out = {}
    for _, value in ipairs(first or {}) do
        out[#out + 1] = value
    end
    for _, value in ipairs(second or {}) do
        out[#out + 1] = value
    end
    return out
end

-- Words for `mantle.battery.state`'s seven UPower names. The pending phrases say only what UPower
-- observed: it reports `PendingCharge` at every plug-in, and its `ChargeEndThreshold` disagrees with
-- sysfs here, so neither state can claim a charge limit.
local BATTERY_PHRASES = {
    Charging = "charging",
    Discharging = "discharging",
    Empty = "empty",
    FullyCharged = "full",
    PendingCharge = "waiting to charge",
    PendingDischarge = "waiting to discharge",
    Unknown = "state unknown",
}

function util.battery_phrase(state)
    return BATTERY_PHRASES[state] or "state unknown"
end

-- `", 2h 14m left"`, or `""`: UPower estimates one duration at a time and neither while learning the
-- rate, so an empty answer is ordinary in the first minute after a plug or a boot.
function util.battery_eta(b)
    local seconds, suffix
    if b.time_to_empty then
        seconds, suffix = b.time_to_empty, "left"
    elseif b.time_to_full then
        seconds, suffix = b.time_to_full, "to full"
    else
        return ""
    end
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then
        return string.format(", %dh %02dm %s", hours, minutes, suffix)
    end
    return string.format(", %dm %s", minutes, suffix)
end

function util.battery_is_draining(state)
    return state == "Discharging" or state == "Empty"
end

-- Thresholds as whole numbers; one table keeps the pill, two notifications, and automatic suspend
-- in agreement.
util.battery_thresholds = { low = 20, critical = 10, suspend = 8 }

-- Whether `b` drains at or under `percent`. Every threshold uses this gate, so 14% with the charger
-- in cannot turn red.
function util.battery_at_most(b, percent)
    return b ~= nil and b.present and util.battery_is_draining(b.state) and b.percent <= percent
end

-- Five-level glyph plus the two cable states. Takes the raw payload, so a `nil` battery draws the AC
-- glyph rather than needing a branch at the caller.
function util.battery_glyph(b)
    local icons = require("config.icons")
    if b == nil or not b.present then
        return icons.battery_ac
    end
    -- Deliberately inverted: charging is the ordinary state on a machine with a charge limit, so it
    -- draws the plug and only a stopped charge gets the distinct bolt.
    if b.state == "PendingCharge" then
        return icons.battery_pending
    end
    if b.state == "Charging" or b.state == "FullyCharged" then
        return icons.battery_ac
    end
    -- Five buckets over 0..100. Lua's 1-based indexing makes 100% bucket 5, not an out-of-range 6.
    local bucket = math.floor((b.percent or 0) / 20) + 1
    return icons.battery_levels[math.max(1, math.min(5, bucket))]
end

-- An `app_id` through `mantle.applications.by_app_id`. Callers spell it as a desktop file id, a
-- toplevel `app_id` or a StatusNotifierItem `Id`, so fold the caller's spelling; the map's keys are
-- already folded.
function util.app_entry(applications, app_id)
    if applications == nil or app_id == nil or app_id == "" then
        return nil
    end
    local by_app_id = applications.by_app_id
    if by_app_id == nil then
        return nil
    end
    return by_app_id[app_id] or by_app_id[string.lower(app_id)]
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
    local icons = require("config.icons")
    for _, hint in ipairs(AUDIO_DEVICE_HINTS) do
        local value = device and device[hint[1]]
        if value and value:find(hint[2]) then
            return icons[is_input and hint[4] or hint[3]]
        end
    end
end

-- Raw `mantle.audio`, not a signal, so callers choose their `nil` behavior. Nerd Font glyphs rather
-- than themed icons, which the OSD could not tint.
function util.volume_glyph(a)
    local icons = require("config.icons")
    if a == nil or a.volume == nil then
        return "--"
    elseif a.muted then
        return icons.vol_muted
    end
    local percent = a.volume * 100
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
function util.network_glyph(n)
    local icons = require("config.icons")
    if n == nil then
        return icons.wifi_none
    end
    if n.ssid == "Ethernet" then
        return icons.ethernet
    end
    -- A dead radio and a live one joined to nothing are different pictures.
    if not n.networking_enabled or not n.wifi_enabled then
        return icons.wifi_off
    end
    if n.ssid == nil then
        return icons.wifi_none
    end
    return icons.wifi[util.signal_tier(n.strength)]
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
    local theme = require("config.theme")
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
---@param n NetworkState?
---@return AccessPointInfo? # The associated access point, or `nil`.
function util.active_access_point(n)
    for _, ap in ipairs((n and n.available_networks) or {}) do
        if ap.active then
            return ap
        end
    end
    return nil
end

-- A codepoint budget, the exception to `components/cell.lua`'s pixel-box rule: centre-zone modules
-- need content-sized nodes between two `Fill` sides, and bounding them pushed short labels off
-- centre. ponytail: codepoints are a ragged pixel width. Wants a `text.max_width` that measures and
-- elides while reporting the string's own width when it fits -- a layout change, not config.
function util.truncate(value, limit)
    local s = tostring(value or "")
    local count = utf8.len(s)
    if count == nil or count <= limit then
        return s
    end
    return s:sub(1, utf8.offset(s, limit + 1) - 1) .. "..."
end

function util.shown_when(signal, predicate)
    return signal:map(function(value)
        if value == nil then
            return false
        end
        local ok, shown = pcall(predicate, value)
        return ok and shown or false
    end)
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
    if value == nil then
        return false
    end
    local ok, result = pcall(read, value)
    return ok and result == true
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

local auto_english_saved = -1
local auto_english_active_count = 0

-- Switches to layout 0 (English) when `capability.active` becomes true, restoring the prior layout on false.
function util.auto_english_layout(capability)
    capability:on_change(function(state, previous)
        local was_active = previous ~= nil and previous.active
        if state ~= nil and state.active and not was_active then
            if auto_english_active_count == 0 then
                local k = mantle.keyboard:get()
                local idx = k and k.active_layout_index or 0
                if idx > 0 then
                    auto_english_saved = idx
                    mantle.keyboard:invoke("switch_layout", 0)
                else
                    auto_english_saved = -1
                end
            end
            auto_english_active_count = auto_english_active_count + 1
        elseif (state == nil or not state.active) and was_active then
            auto_english_active_count = math.max(0, auto_english_active_count - 1)
            if auto_english_active_count == 0 and auto_english_saved >= 0 then
                mantle.keyboard:invoke("switch_layout", auto_english_saved)
                auto_english_saved = -1
            end
        end
    end)
end

return util
