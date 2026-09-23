-- Glyphs the bar draws by name, as private-use codepoints for `text`, which takes `foreground`. A
-- themed `icon` raster keeps its own colours and cannot be tinted. `shell.lua`'s font chain picks
-- Nerd Font per glyph, and without it these are tofu. `\u{...}` keeps the source ASCII.
local icons           = {}

-- Left zone.
icons.power           = "\u{EAD2}"  -- nf-cod-debug_restart_frame
icons.logout          = "\u{F0343}"
icons.shutdown        = "\u{23FB}"  -- IEC 5009 power symbol, not a Nerd Font glyph
icons.lock            = "\u{F033E}"
icons.sleep           = "\u{F04B2}" -- nf-md-power_sleep
icons.settings        = "\u{F0493}"
icons.launcher        = "\u{F035C}"
icons.web             = "\u{F059F}" -- nf-md-web, the launcher's open-link row
icons.search          = "\u{F0349}" -- nf-md-magnify, its web-search row
icons.calc            = "\u{F00EC}" -- nf-md-calculator, its calculator row
icons.wallpaper       = "\u{F02E9}"

-- Updates, in test order.
icons.updating        = "\u{F0996}"
icons.update_err      = "\u{F0159}"
icons.checking        = "\u{F085}"
icons.updates         = "\u{F019}"
icons.up_to_date      = "\u{F00AA}"

-- `battery_levels` runs 1..5, empty to full.
icons.battery_ac      = "\u{F1E6}"
icons.battery_pending = "\u{F0084}"
icons.battery_levels  = { "\u{F244}", "\u{F243}", "\u{F242}", "\u{F241}", "\u{F240}" }

icons.brightness      = "\u{F00DE}"
icons.keyboard        = "\u{F030C}"
icons.caps_lock       = "\u{F0A9B}"
icons.num_lock        = "\u{F03A0}"
icons.lan             = "\u{F0317}"
icons.lan_off         = "\u{F0318}"
icons.speaker         = "\u{F04C3}"
icons.check           = "\u{F012C}"
icons.mixer           = "\u{F04E1}"
icons.music_note      = "\u{F075A}"
icons.headphones      = "\u{F02CB}"
icons.headset         = "\u{F02CE}"
icons.phone           = "\u{F03F2}"
icons.television      = "\u{F0502}"
icons.usb             = "\u{F0553}"
icons.webcam          = "\u{F05A0}"

-- Audio levels, plus the muted toggle glyph.
icons.vol_muted       = "\u{F075F}"
icons.vol_zero        = "\u{F0581}"
icons.vol_low         = "\u{F057F}"
icons.vol_mid         = "\u{F0580}"
icons.vol_high        = "\u{F057E}"

-- `wifi` runs 1..4, weakest to strongest.
icons.wifi            = { "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}" }
icons.wifi_off        = "\u{F092E}"
icons.wifi_none       = "\u{F092D}"
-- The row that starts a hidden join. A network that broadcasts no SSID has no scanned row to
-- click, so this stands for the one that is not listed.
icons.wifi_hidden     = "\u{F05AA}"
icons.ethernet        = "\u{F0200}"

icons.bt_off          = "\u{F00B2}"
icons.bt_on           = "\u{F00AF}"
icons.bt_conn         = "\u{F00B1}"
-- The Bluetooth panel's two tiles, the "Visible" and "Scan" glyphs.
icons.bt_visible      = "\u{F043E}"
icons.bt_scan         = "\u{F0018}"

-- Notifications, plus `bell_off` for the clock glyph when there are none.
icons.bell            = "\u{F0A2}"
icons.bell_active     = "\u{F116B}"
icons.bell_off        = "\u{F009B}"

-- Privacy uses Font Awesome.
icons.mic_on          = "\u{F130}"
icons.mic_off         = "\u{F131}"
icons.camera          = "\u{F030}"
icons.screenshare     = "\u{F108}"

icons.play            = "\u{F040A}"
icons.pause           = "\u{F03E4}"
-- The transport row's note is F0386, not the F075A `music_note` of an audio stream row. The panel
-- means "the media player", and the stream row means "a sound".
icons.media           = "\u{F0386}"
icons.previous        = "\u{F04AE}"
icons.next            = "\u{F04AD}"
icons.rewind          = "\u{F11F9}"
icons.fast_forward    = "\u{F11F8}"
icons.player_switch   = "\u{F0CB0}"
-- F035B is CPU, the square processor with pins, and F061A is RAM, the DIMM stick.
icons.cpu             = "\u{F035B}"
icons.ram             = "\u{F061A}"
icons.gpu             = "\u{F08AE}"

-- One per Bluetooth `category`, so a mouse or headset does not get the generic glyph.
icons.device          = {
    keyboard   = "\u{F030C}",
    mouse      = "\u{F037D}",
    headphones = "\u{F02CB}",
    headset    = "\u{F02CE}",
    phone      = "\u{F011C}",
    computer   = "\u{F0322}",
    generic    = "\u{F00AF}",
}

-- `idle` means nothing holds the system awake, and `awake` is the coffee cup of a manual hold.
-- `display` is the monitor DPMS state. Suspend reuses `sleep` rather than a near-duplicate glyph.
icons.idle            = "\u{F0FAA}"
icons.awake           = "\u{F0176}"
icons.display         = "\u{F0379}"

icons.refresh         = "\u{F0450}"
icons.copy            = "\u{F018F}"

-- The lock screen buckets the WMO code into six Nerd Font glyphs for its status line. The sidebar
-- widget draws the emoji instead, as the picture on a forecast card.
icons.weather_sunny   = "\u{F0599}"
icons.weather_fog     = "\u{F0591}"
icons.weather_rain    = "\u{F0597}"
icons.weather_snow    = "\u{F0598}"
icons.weather_storm   = "\u{F0593}"
icons.weather_cloud   = "\u{F0590}"
icons.clear_all       = "\u{F0234}"

-- `components/panel_action_icon.lua` row actions that delete a saved network or paired device, or cut
-- a live connection.
icons.trash           = "\u{F0A7A}"
icons.disconnect      = "\u{F1616}"

-- Screen recorder. The bar has three states, idle, recording and paused, and the panel names the two
-- captures it can start. `record` is the header's glyph. `record_start` is the bar's idle circle, the
-- one that says "this button records".
icons.record          = "\u{F044A}"
icons.record_start    = "\u{F07A1}"
icons.record_stop     = "\u{F04DB}"
icons.record_paused   = "\u{F03E7}"
icons.region          = "\u{F019E}"
icons.folder          = "\u{F024B}"
-- The three quality words, ranked by a needle. A slow gauge is the smallest files, a fast one the
-- sharpest.
icons.quality_low     = "\u{F0F86}"
icons.quality_medium  = "\u{F0F85}"
icons.quality_high    = "\u{F04C5}"
icons.file_mp4        = "\u{F022B}"
icons.file_mkv        = "\u{F0FCE}"

icons.warning         = "\u{F0026}"
icons.close           = "\u{F0156}"

-- Chevrons expand and collapse a notification group or message. `send` submits the inline reply.
icons.chevron_up      = "\u{F0143}"
icons.chevron_down    = "\u{F0140}"
-- Collapsed rows point right rather than up, because the row opens downwards and nothing above it
-- moves.
icons.chevron_right   = "\u{F0142}"
icons.send            = "\u{F048A}"
icons.plus            = "\u{F0415}"
icons.minus           = "\u{F0374}"

return icons
