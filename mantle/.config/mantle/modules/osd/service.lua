-- A card for two seconds on a system change. Push-driven, so a volume key, `wpctl` and the bar
-- button share it. `level` selects the shape (track versus glyph tile); `modules/osd/popup.lua`
-- only draws. A less important card is dropped while a higher-priority one shows, which is what
-- keeps the charger edge's brightness step from replacing "charger connected".
local theme = require("config.theme")
local icons = require("config.icons")
local audio_lib = require("lib.audio")

local osd = {}

-- Priority order, lower first. Toggles a key press asked for outrank levels, so a held volume key
-- cannot swallow caps lock. Unlisted kinds are least important.
local PRIORITY = {
    battery = 0,
    audio_device = 1,
    networking = 2,
    bluetooth = 2,
    dnd = 2,
    locks = 2,
    layout = 2,
    volume = 3,
    brightness = 3,
    backlight = 3,
}

osd.entry = state("osd_entry", { kind = "", glyph = "", text = "" })
-- Every `show` writes a fresh table, which `pulse` counts as a change, so each card restarts the two
-- seconds. It starts false, so a card up at reload hides rather than lingering with no timer.
osd.visible = pulse(osd.entry, 2000)

-- `entry` is `{ glyph, text, level?, color? }`; `level` in 0..100 selects the track layout.
function osd.show(kind, entry)
    local current = osd.entry:get()
    if osd.visible:get() and current.kind ~= kind and (PRIORITY[kind] or 9) > (PRIORITY[current.kind] or 9) then
        return
    end
    entry.kind = kind
    osd.entry:set(entry)
end

-- An off state greys the tile, so "Caps lock off" and "Caps lock on" differ before the words.
local function toggle(kind, on, what, glyph_on, glyph_off)
    osd.show(kind, {
        glyph = not on and glyph_off or glyph_on,
        text = what .. (on and " on" or " off"),
        color = not on and theme.DIM or nil,
    })
end

local function percent_level(kind, glyph, percent)
    osd.show(kind, { glyph = glyph, text = string.format("%d%%", percent), level = percent, color = theme.YELLOW })
end

-- Every handler skips the first push (`previous == nil`): it reports learned state, not a change.

mantle.audio:on_change(function(audio, previous)
    if previous == nil then
        return
    end
    local sink, previous_sink = audio_lib.default_sink(audio), audio_lib.default_sink(previous)
    local percent = sink and sink.volume and math.floor(sink.volume + 0.5)
    local was = previous_sink and previous_sink.volume and math.floor(previous_sink.volume + 0.5)
    if percent and was and (sink.muted ~= previous_sink.muted or percent ~= was) then
        -- Muted keeps the level and greys it: the volume is still set, only silenced.
        osd.show("volume", {
            glyph = audio_lib.volume_glyph(audio),
            text = sink.muted and "Muted" or string.format("%d%%", percent),
            level = percent / audio_lib.MAX_VOLUME * 100,
            color = sink.muted and theme.DIM or theme.ACCENT,
        })
    end
    if sink and sink.name ~= (previous_sink and previous_sink.name) then
        osd.show("audio_device", {
            glyph = audio_lib.audio_device_glyph(sink, false) or icons.speaker,
            text = audio_lib.device_name(sink),
        })
    end
end)

mantle.brightness:on_change(function(brightness, previous)
    if previous and brightness.percent ~= previous.percent then
        percent_level("brightness", icons.brightness, brightness.percent)
    end
end)

mantle.network:on_change(function(network, previous)
    if previous and network.networking_enabled ~= previous.networking_enabled then
        toggle("networking", network.networking_enabled, "Networking", icons.lan, icons.lan_off)
    end
end)

mantle.bluetooth:on_change(function(bluetooth, previous)
    if previous and bluetooth.enabled ~= previous.enabled then
        toggle("bluetooth", bluetooth.enabled, "Bluetooth", icons.bt_on, icons.bt_off)
    end
end)

mantle.notifications:on_change(function(notifications, previous)
    if previous and notifications.dnd ~= previous.dnd then
        toggle("dnd", notifications.dnd, "Do not disturb", icons.bell_off, icons.bell)
    end
end)

mantle.keyboard:on_change(function(keyboard, previous)
    if previous == nil then
        return
    end
    if keyboard.active_layout ~= previous.active_layout and keyboard.active_layout ~= "" then
        osd.show("layout", { glyph = icons.keyboard, text = keyboard.active_layout })
    end
    if keyboard.caps_lock ~= previous.caps_lock then
        toggle("locks", keyboard.caps_lock, "Caps lock", icons.caps_lock)
    end
    if keyboard.num_lock ~= previous.num_lock then
        toggle("locks", keyboard.num_lock, "Num lock", icons.num_lock)
    end
    if keyboard.scroll_lock ~= previous.scroll_lock then
        toggle("locks", keyboard.scroll_lock, "Scroll lock", icons.keyboard)
    end
    if keyboard.backlight_percent and keyboard.backlight_percent ~= previous.backlight_percent then
        percent_level("backlight", icons.keyboard, keyboard.backlight_percent)
    end
end)

return osd
