-- Pure helpers with no nodes, kept out of `components/`.
local util = {}

-- Capability signals are `nil` until the first Supervisor snapshot, and payload readers may raise.
-- Map `nil` to "--" and reader errors to "!", leaving each module one line for its payload.
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

-- Human-readable words for `mantle.battery.state`'s seven UPower names, shared by the pill tooltip,
-- power menu, and lock screen.
-- `PendingCharge` matters when a laptop with `charge_control_end_threshold` set sits plugged in at
-- the limit. Neither pending state *means* the limit, though. UPower says only "plugged in and not
-- charging", and this machine reports it for a few seconds at every plug-in while the asus driver
-- still reads `Not charging`. The number is not available to say otherwise: UPower 1.91 carries
-- `ChargeEndThreshold` but reports 80 with `ChargeThresholdEnabled` false here, against sysfs's 70,
-- because asusd writes it behind UPower. So both phrases say what UPower observed and leave the
-- cause to whoever set the limit.
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

-- Battery display helpers: warnings use `Discharging` and `Empty`. `PendingDischarge` does not warn
-- because it is not draining -- by its name the discharge is pending, and UPower defines it no
-- further. `battery_eta` returns `", 2h 14m left"` or `""`. UPower
-- UPower estimates one duration at a time and neither while learning the rate, so the empty string
-- is common during the first minute after a plug or a boot, not an error.
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

-- Five-level glyph plus the two cable states, shared by `modules/bar/indicators/battery.lua` and
-- the lock card's status row. It takes the raw payload so a caller with a `nil` battery still gets
-- the AC glyph rather than a branch of its own.
-- `PendingCharge` gets the bolt; `Charging` and `FullyCharged` get the plug. That is not the obvious
-- order, explained at the branch below.
function util.battery_glyph(b)
    local icons = require("config.icons")
    if b == nil or not b.present then
        return icons.battery_ac
    end
    -- Not the obvious order: `PendingCharge` is tested *first* and gets the charging bolt, and
    -- everything else on mains gets the plug -- so a battery that is actually charging draws the
    -- plug, and only a stopped one draws the bolt. That reads correctly on a machine with a limit
    -- set, where charging is the ordinary state and stopped is the one worth a distinct glyph.
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

-- Resolve an `app_id` through `mantle.applications.by_app_id` (ADR-0061). Callers supply different
-- spellings: a desktop file id (`modules/global/launcher.lua`), compositor toplevel `app_id`
-- (`modules/bar/indicators/active_window.lua`), or StatusNotifierItem `Id`
-- (`modules/bar/indicators/sys_tray.lua`).
-- Fold only the caller's spelling here; the map already carries case-folded keys. Doing it in Rust
-- would make the capability guess which caller key was intended.
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

-- Shared icon mapping for `modules/bar/indicators/volume.lua` and `modules/osd/popup.lua`. It
-- takes raw `mantle.audio`, not a signal, so callers choose their `nil` behavior. `--` without a
-- volume, muted, then four steps by level, as Nerd Font glyphs rather than themed icon names: the
-- OSD accent-tints them and themed icons cannot be tinted.
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
    -- A dead radio and a live one joined to nothing are different pictures. `wifi_enabled` was
    -- added to `NetworkState` so the first can be drawn.
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

-- Bluetooth devices by shown name, then MAC. The Supervisor builds both lists from a `HashMap`, so
-- their order can change on any rebuild and rows would swap under the pointer. `"\0"` sorts below
-- every name character, so a name that prefixes another still sorts first.
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

-- A band's colour plus the short label the panel draws beside the bars: "6G", "5G", "2.4".
-- Shared because the bar tints its glyph by the associated band and the panel tints every row; two
-- copies drift apart. Like
-- `volume_glyph`, it takes raw payload with no signal, and the caller decides about `nil`. A `nil`
-- label with `FG` is the honest answer for ethernet and for a band nothing reported.
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

-- The `available_networks` entry the link is actually on. `NetworkState` carries `ssid` and
-- `strength` for the association but not its band, so anything band-shaped has to come back through
-- the AP list. A wired link has no entry here, which is why callers need no separate ethernet case.
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

-- Hide a module with no content instead of showing a "--" pill. `visible` is a signal-bound base
-- property, so hidden children are skipped by row positioning rather than laid out at zero
-- width. Use a codepoint budget here, the exception to `components/cell.lua`'s pixel-box rule.
-- Centre-zone modules need content-sized nodes between two `Fill` sides; bounding them made short
-- "(1) WhatsApp" sit a hundred pixels left of centre. ponytail: "WWWW" and "iiii" share four
-- codepoints but differ in width, so this cuts to a ragged pixel width. Upgrade with
-- `text.max_width`, letting the engine measure/elide while reporting the string's own width when it
-- fits; that requires a layout change, not config.
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

-- `signal` or its value from up to `ms` ago: true while the source is true and for `ms` after it
-- drops. The hidden subtree keeps its content (ADR-0124) and `delay` keeps the surface mapped while
-- the exit tween runs (ADR-0146).
function util.linger(signal, ms)
    return computed({ signal, delay(signal, ms) }, function(now, was)
        -- `== true` rather than `now or was`, which returns whatever `delay` holds. `delay` answers
        -- the source's older value, and before the first change settles that is the property's
        -- identity, `0` -- a number Lua calls truthy and the engine refuses, so `modal_host`'s
        -- `visible` would get `Integer(0)` and the whole re-resolve would be dropped. Every caller
        -- here feeds a `visible`, so the boolean is the helper's job to guarantee.
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

-- Whitespace off both ends. Parenthesised because `gsub` also returns its count, and a caller
-- writing `return util.trim(x)` would otherwise return two values.
function util.trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Thousands separators into an already-formatted number, for the launcher's calculator and
-- currency rows. Reverse, group, reverse, because grouping from the right is what makes "1234"
-- read as "1,234" rather than "123,4".
function util.thousands(formatted)
    local sign, digits, rest = formatted:match("^(%-?)(%d+)(.*)$")
    if not digits then
        return formatted
    end
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. grouped .. rest
end

return util
