-- A card for two seconds on a system change. Push-driven, so a volume key, `wpctl` and the bar
-- button share it. `level` selects the shape (track versus glyph tile); `modules/osd/popup.lua`
-- only draws. A less important card is dropped while a higher-priority one shows, which is what
-- keeps the charger edge's brightness step from replacing "charger connected".
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")

local osd = {}

-- Priority order, lower first. Unlisted kinds are least important.
local PRIORITY = { battery = 0, audio_device = 1, networking = 2, bluetooth = 2, volume = 3, brightness = 3 }

osd.entry = state("osd_entry", { kind = "", glyph = "", text = "" })
osd.visible = state("osd_visible", false)

-- `process.run("sleep", ...)` is the only timer. `ProcessHandle:kill()` does not cancel queued
-- `exit_cb`, so a request counter distinguishes a newer card from the older sleep; killing alone
-- would let the old callback hide the new card.
local SECONDS = "2"
local request = 0

-- `entry` is `{ glyph, text, level?, color? }`; `level` in 0..100 selects the track layout.
function osd.show(kind, entry)
    local current = osd.entry:get()
    if osd.visible:get() and current.kind ~= kind and (PRIORITY[kind] or 9) > (PRIORITY[current.kind] or 9) then
        return
    end
    entry.kind = kind
    osd.entry:set(entry)
    osd.visible:set(true)
    request = request + 1
    local this_request = request
    process.run("sleep", { SECONDS }, function() end, function()
        if this_request == request then
            osd.visible:set(false)
        end
    end)
end

local function toggle(kind, on, glyph_on, glyph_off, what)
    osd.show(kind, { glyph = on and glyph_on or glyph_off, text = what .. (on and " on" or " off") })
end

local function percent_level(kind, glyph, percent)
    osd.show(kind, { glyph = glyph, text = string.format("%d%%", percent), level = percent, color = theme.YELLOW })
end

-- Every handler skips the first push (`previous == nil`): it reports learned state, not a change.

mantle.audio:on_change(function(audio, previous)
    if previous == nil then
        return
    end
    local percent = audio.volume and math.floor(audio.volume * 100 + 0.5)
    local was = previous.volume and math.floor(previous.volume * 100 + 0.5)
    if percent and was and (audio.muted ~= previous.muted or percent ~= was) then
        osd.show("volume", {
            glyph = util.volume_glyph(audio),
            text = audio.muted and "Muted" or string.format("%d%%", percent),
            level = audio.muted and 0 or percent / util.MAX_VOLUME,
            color = theme.ACCENT,
        })
    end
    local sink, previous_sink = util.active_device(audio.sinks), util.active_device(previous.sinks)
    if sink and sink.name ~= (previous_sink and previous_sink.name) then
        osd.show("audio_device", { glyph = util.audio_device_glyph(sink, false) or icons.speaker, text = sink.name })
    end
end)

mantle.brightness:on_change(function(brightness, previous)
    if previous and brightness.percent ~= previous.percent then
        percent_level("brightness", icons.brightness, brightness.percent)
    end
end)

mantle.network:on_change(function(network, previous)
    if previous and network.networking_enabled ~= previous.networking_enabled then
        toggle("networking", network.networking_enabled, icons.lan, icons.lan_off, "Networking")
    end
end)

mantle.bluetooth:on_change(function(bluetooth, previous)
    if previous and bluetooth.enabled ~= previous.enabled then
        toggle("bluetooth", bluetooth.enabled, icons.bt_on, icons.bt_off, "Bluetooth")
    end
end)

mantle.notifications:on_change(function(notifications, previous)
    if previous and notifications.dnd ~= previous.dnd then
        toggle("dnd", notifications.dnd, icons.bell_off, icons.bell, "Do not disturb")
    end
end)

mantle.keyboard:on_change(function(keyboard, previous)
    if previous == nil then
        return
    end
    if keyboard.active_layout ~= previous.active_layout and keyboard.active_layout ~= "" then
        osd.show("layout", { glyph = icons.keyboard, text = "Layout: " .. keyboard.active_layout })
    end
    if keyboard.caps_lock ~= previous.caps_lock then
        toggle("locks", keyboard.caps_lock, icons.caps_lock, icons.caps_lock, "Caps lock")
    end
    if keyboard.num_lock ~= previous.num_lock then
        toggle("locks", keyboard.num_lock, icons.num_lock, icons.num_lock, "Num lock")
    end
    if keyboard.scroll_lock ~= previous.scroll_lock then
        toggle("locks", keyboard.scroll_lock, icons.keyboard, icons.keyboard, "Scroll lock")
    end
    if keyboard.backlight_pct >= 0 and keyboard.backlight_pct ~= previous.backlight_pct then
        percent_level("backlight", icons.keyboard, keyboard.backlight_pct)
    end
end)

return osd
