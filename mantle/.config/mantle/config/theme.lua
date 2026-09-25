-- Catppuccin Mocha. An invented palette would be a worse version of one already balanced.
-- Shared tokens live here because every `shell.lua` module reads them and no module owns them.
-- The module cache clears before each re-evaluation, so edits recolour the bar in place.
local theme = {}

-- `s(base)` scales non-colour tokens from 1080p values, read once during evaluation from the first
-- output. `mantle.screens` is the only signal available then; every other
-- capability reads `nil` until its first snapshot. Logical pixels, so a 3840x2160 panel at scale 2
-- arrives as 1080 and `screen.scale` is not a second divisor.
--
-- ponytail: hotplug is not followed, since tokens are numbers baked into node maps at evaluation.
-- Upgrade `s()` to return a signal, which consumers already accept, when a second monitor matters.
local SCREEN = (mantle and mantle.screens and mantle.screens:get() or {})[1] or {}

-- 1080p is this config's design height, so an evaluation with no screens measures the live bar.
local MAIN_WIDTH = SCREEN.width or 1920
local MAIN_HEIGHT = SCREEN.height or 1080

local SCALE = math.max(0.75, math.min(1.4, 0.9 + ((MAIN_HEIGHT - 1080) / 360) * 0.1))

-- `min` is a small-screen floor, not a default. A 10px label at 0.75 is 8px and legible, and an 8px
-- icon becomes an illegible 6px smudge.
function theme.s(base, min)
    return math.max(min or 0, math.floor(base * SCALE + 0.5))
end

local s = theme.s

-- Colour helpers speak the engine's `#RRGGBB`/`#RRGGBBAA` strings, so results feed `background`.
-- `channels` gives red, green and blue bytes plus alpha as a fraction; missing alpha means opaque.
local function channels(hex)
    local digits = hex:gsub("^#", "")
    return tonumber(digits:sub(1, 2), 16) or 0, tonumber(digits:sub(3, 4), 16) or 0, tonumber(digits:sub(5, 6), 16) or 0,
        (tonumber(digits:sub(7, 8), 16) or 255) / 255
end

-- Replaces rather than multiplies alpha; otherwise
-- `with_opacity(BG_SUBTLE, 0.5)` would differ from `with_opacity(BG, 0.5)`.
function theme.with_opacity(hex, alpha)
    local r, g, b = channels(hex)
    return string.format("#%02x%02x%02x%02x", r, g, b, math.floor(math.max(0, math.min(1, alpha)) * 255 + 0.5))
end

-- Linear blend toward white, like `Qt.lighter`. HSV is unnecessary for these small steps. Alpha is
-- kept, so a translucent ground lifts without turning opaque.
local function lighten(hex, amount)
    local r, g, b, alpha = channels(hex)
    local mix = function(channel)
        return math.floor(channel + (255 - channel) * amount + 0.5)
    end
    return string.format("#%02x%02x%02x%02x", mix(r), mix(g), mix(b), math.floor(alpha * 255 + 0.5))
end

-- WCAG relative luminance at the 0.179 threshold, compositing translucent colours over `BG` first.
-- Alone, the swatch reads light-purple `ON_HOVER` at 45% as bright, yet it reaches the screen dark.
function theme.text_contrast(hex)
    local function linear(byte)
        local c = byte / 255
        if c <= 0.04045 then
            return c / 12.92
        end
        return ((c + 0.055) / 1.055) ^ 2.4
    end
    local r, g, b, mix = channels(hex)
    if mix < 1 then
        local gr, gg, gb = channels(theme.BG)
        r, g, b = r * mix + gr * (1 - mix), g * mix + gg * (1 - mix), b * mix + gb * (1 - mix)
    end
    local luminance = 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    return luminance > 0.179 and "#000000ff" or "#ffffffff"
end

-- The hover ground for any `background`: glass takes its own tint, anything else the 0.16 lift.
function theme.hover(color)
    return color == theme.GLASS_CONTROL and theme.GLASS_CONTROL_HOVER or lighten(color, 0.16)
end

-- `opacity` multiplies down the subtree, so dimming a control is one property, not a colour per part.
theme.opacity                  = {
    subtle   = 0.15,
    light    = 0.25,
    medium   = 0.35,
    disabled = 0.5,
    muted    = 0.7,
    strong   = 0.8,
}

-- The swatches everything else derives from.
theme.BG                       = "#1e1e2eff"
theme.MANTLE                   = "#181825ff"
theme.CRUST                    = "#11111bff"
theme.SURFACE                  = "#313244ff"
theme.FG                       = "#cdd6f4ff"
-- Catppuccin subtext0, since overlay0 reads as disabled rather than secondary. The one secondary-text
-- colour. Faded controls use node `opacity`.
theme.DIM                      = "#a6adc8ff"
-- Mauve, not blue.
theme.ACCENT                   = "#cba6f7ff"
theme.GREEN                    = "#a6e3a1ff"
theme.YELLOW                   = "#f9e2afff"
theme.PEACH                    = "#fab387ff"
theme.RED                      = "#f38ba8ff"
theme.INACTIVE                 = "#45475aff"
theme.ON_HOVER                 = "#a28dcdff"
theme.CLEAR                    = "#00000000"

-- Derived steps from the swatches, so a scheme swap edits only those.
theme.ELEVATED                 = lighten(theme.BG, 0.12)
theme.ELEVATED_HOVER           = lighten(theme.BG, 0.18)
-- Dimmer than DIM, for a bar indicator with nothing connected. Half, not a third: on glass over a
-- bright wallpaper a third vanished.
theme.TEXT_OFF                 = theme.with_opacity(theme.DIM, theme.opacity.disabled)
-- Tertiary text: section labels and empty-state hints, a step below `DIM`.
theme.TEXT_MUTED               = theme.with_opacity(theme.DIM, theme.opacity.muted)
theme.BORDER                   = theme.with_opacity(theme.SURFACE, 0.75)
theme.BORDER_SUBTLE            = theme.with_opacity(theme.SURFACE, 0.35)
-- The shared card ground, so a card reads as a sheet above the bar rather than the same tone.
theme.GLASS                    = theme.with_opacity(theme.MANTLE, 0.88)
theme.GLASS_CONTENT            = theme.with_opacity(theme.ELEVATED, 0.46)
-- A text field sits on the base tone, not the elevated one, so a search box reads as a well cut into
-- its card rather than a second card.
theme.GLASS_INPUT              = theme.with_opacity(theme.BG, 0.62)
theme.GLASS_HOVER              = theme.with_opacity(theme.ELEVATED_HOVER, 0.62)
theme.ACCENT_SUBTLE            = theme.with_opacity(theme.ACCENT, theme.opacity.subtle)
theme.ACCENT_LIGHT             = theme.with_opacity(theme.ACCENT, theme.opacity.light)
theme.ACCENT_MEDIUM            = theme.with_opacity(theme.ACCENT, theme.opacity.medium)
-- Hover for an opaque `ACCENT` ground. The three alpha tints cannot lift an opaque colour, so it
-- is lightened instead.
theme.ACCENT_HOVER             = lighten(theme.ACCENT, 0.16)
-- The same lift for an opaque `RED` ground.
theme.RED_HOVER                = lighten(theme.RED, 0.16)
-- Ink for text on a glass control under the pointer, lifted the same 0.16 as the two grounds
-- above. Panel headers rest at `FG` and reach this on hover; `ACCENT` marks the open state.
theme.TEXT_ACTIVE              = lighten(theme.FG, 0.16)
-- The plate behind a notification card's application icon.
theme.BG_SUBTLE                = theme.with_opacity(theme.BG, theme.opacity.subtle)

-- The chrome is translucent throughout. Opaque controls turn floating pills into filled rectangles,
-- and radius cannot fix it. Alpha reaches the compositor, so the layer composites against wallpaper.
theme.GLASS_SURFACE            = theme.with_opacity(theme.BG, 0.5)
theme.GLASS_CONTROL            = theme.with_opacity(theme.INACTIVE, 0.42)
theme.TOOLTIP_FG               = theme.text_contrast(theme.GLASS_SURFACE)
-- 0.45, not 0.68. On a glass control over wallpaper, 0.68 makes hover the bar's brightest element,
-- and 0.45 keeps the glyph white instead of inverting it.
theme.GLASS_CONTROL_HOVER      = theme.with_opacity(theme.ON_HOVER, 0.45)
theme.GLASS_BORDER             = theme.with_opacity(theme.FG, 0.18)
theme.GLASS_BORDER_HOVER       = theme.with_opacity(theme.FG, 0.34)

-- 0.45, not 0.88, because the scrim lies over wallpaper, where 0.88 is a blackout.
theme.SCRIM                    = theme.with_opacity(theme.BG, 0.45)

-- Named steps keep `spacing.sm` the same in bar and panel, and let one edit change both.
theme.spacing                  = {
    xs = s(4, 2),
    sm = s(8, 4),
    md = s(12, 8),
    lg = s(16, 10),
    xl = s(24, 16),
}

-- Named on every icon node. `Mono` keeps an indicator to one cell, unlike the `Propo` body face.
theme.icon_font                = "JetBrainsMono Nerd Font Mono"
-- Command output, so columns in a log line up.
theme.mono_font                = theme.icon_font

theme.font                     = {
    xs  = s(10, 8),
    sm  = s(12, 10),
    md  = s(14, 12),
    lg  = s(16, 14),
    xl  = s(20, 16),
    xxl = s(28, 20),
}

theme.radius                   = {
    sm = s(6, 4),
    md = s(12, 8),
    lg = s(18, 12),
    xl = s(40, 20),
}

theme.icon                     = {
    xs = s(12, 10),
    sm = s(14, 12),
    md = s(18, 14),
    lg = s(24, 18),
    xl = s(32, 24),
}

-- Keeps adjacent toggles and buttons aligned without pixel literals.
theme.control                  = {
    xs = s(24, 20),
    sm = s(28, 24),
    md = s(34, 28),
    lg = s(42, 34),
    xl = s(52, 42),
}
theme.control_width_lg         = s(48, 40)

theme.border_width             = 1
-- Twice the hairline, for cards floating over wallpaper.
theme.border_width_medium      = 2

-- Surface geometry, shared so a module and its opener cannot disagree.
theme.bar_height               = s(42, 28)

-- `control` sizes panel contents, `item` sizes bar controls. `item_radius` is half `item_height`
-- with its own `s()`, since rounding it separately keeps a circle from a round square.
--
-- `title_limit` is a character budget, not a box, so the centre zone stays content-sized and its
-- midpoint is the bar's.
theme.title_limit              = (MAIN_WIDTH / math.max(1, MAIN_HEIGHT)) > 2.1 and 74 or 47

-- A third of the screen while media is up, so the spectrum has a span to fill.
theme.center_zone_width        = math.floor(MAIN_WIDTH / 3)

theme.item_height              = s(34, 20)
theme.item_width               = s(34, 20)
theme.item_radius              = s(18, 6)
-- Enough for a glyph and "100%"; the bar's non-circular item.
theme.battery_pill_width       = s(80, 60)
-- The hovered volume control holds "150%" plus a drag track.
theme.volume_expanded_width    = s(220, 140)
-- Milliseconds for a node's `animate` table; the engine eases `InOutQuad` by default.
theme.animation_ms             = 147
theme.animation_fast_ms        = 100
-- A pulse rather than a transition, slow enough to read as breathing.
theme.animation_slow_ms        = 250
theme.animation_very_slow_ms   = 400
-- Notification travel, derived so it follows the base rather than pinning 206.
theme.notification_slide_ms    = math.floor(theme.animation_ms * 1.4 + 0.5)
-- How far a selected item's picture grows, shared by the launcher and wallpaper picker.
theme.selected_scale           = 1.1
-- For a fill scrubbed by key repeat. An eased tween restarts from a standstill on every retarget and
-- falls behind, and a spring carries its velocity across. 400/42 is critically
-- damped, and a single press still lands in about a tenth of a second.
theme.spring_tracking          = { spring = { stiffness = 400, damping = 42 } }
-- Bar panels share one card in `modules/shell/panel_host.lua`. A list scrolls past `panel_list_height`,
-- cut between rows by `util.fit_height`, so it needs each row's height: headers take a fixed one.
theme.panel_width              = s(340, 280)
theme.panel_list_height        = s(280, 210)
-- A drag track, so a list of them can be cut between rows.
theme.slider_height            = s(16, 12)
-- The audio panel's device sliders, taller so the label inside stays readable.
theme.audio_slider_height      = s(20, 16)
theme.meter_height             = s(6, 4)
theme.section_header_height    = s(22, 18)
-- Where a closed panel sits before `geometry` has measured it; after that it uses `-height`.
theme.panel_slide              = s(760, 570)
-- History holds the popup's cards plus the weather and sysinfo widgets.
theme.notification_panel_width = s(460, 380)
theme.notification_list_height = s(640, 480)
-- A name and two version columns. 460px still elided `gpu-screen-recorder-git`.
theme.update_panel_width       = s(520, 400)

-- Two named sliders and a mixer.
theme.audio_panel_width        = s(380, 300)

-- An application's own words need more room than the shell's. The 340px card elides
-- "Preferences and settings".
theme.tray_menu_width          = s(300, 240)
-- A guard against runaway menus, not a list budget: an ordinary menu never scrolls its Quit away.
theme.tray_menu_height         = s(560, 420)
-- The idle modal's action rows plus AC and battery columns, each with a timeout and switch.
theme.idle_modal_width         = s(820, 640)
-- A stage's duration bar, eight segments wide enough for "120m"; and the AC/battery picker.
theme.idle_bar_width           = s(440, 340)
theme.idle_picker_width        = s(220, 170)
theme.idle_row_height          = s(60, 46)
-- Timeline track, wide as the card and tall enough for a glyph plus duration per stage, unlike the
-- 6px `components/meter.lua` percentage meter.
theme.idle_track_height        = s(36, 28)
theme.update_list_height       = s(360, 260)
-- Fixed, so versions align down the table; wide enough for `6.1.0.r4.gc8f50c4-1`.
theme.update_version_width     = s(116, 88)
-- Keep the log shorter than the package list; its last dozen lines explain a failure.
theme.update_log_height        = s(200, 150)
-- A traceback's paths wrap at 520px, and the rescue log scrolls rather than filling the screen.
theme.rescue_modal_width       = s(720, 560)
theme.rescue_log_height        = s(320, 240)
-- A radio tile tall enough for a glyph over a word.
theme.panel_toggle_height      = s(56, 44)
-- `components/panel_empty_state.lua`'s height with a glyph, so an empty list reads as a state
-- rather than a gap.
theme.panel_empty_height       = s(120, 90)
theme.notification_width       = s(380, 300)
-- An `item_height` icon square with a few pixels of plate around it.
theme.notification_app_icon    = s(40, 32)
-- Fixed, because a glyph, a bar and a percentage never change length, and a card resizing under a
-- held volume key would be the only thing moving on screen.
theme.osd_width                = s(300, 240)
-- The toggle layout has no bar and holds whatever the system said, so it is content-sized; this
-- floor keeps "num lock on" from drawing a card as narrow as the words.
theme.osd_toggle_min           = s(220, 176)
theme.osd_height               = s(80, 60)
theme.osd_tile                 = s(48, 36)
theme.osd_track                = s(12, 8)
-- Fits "100%" beside the bar, so the bar never jumps as the number changes length.
theme.osd_value_width          = s(52, 40)
-- A short settle, not a swoop: the card acknowledges a key already pressed, dozens of times a day.
theme.osd_slide                = s(12, 8)
theme.osd_bottom_margin        = s(132, 90)
-- The polkit and lock cards, narrower than the launcher because each holds a line or two and one field.
theme.dialog_width             = s(450, 360)
-- A dialog that is not a modal sits this far below the top edge, clear of the bar.
theme.dialog_top_margin        = s(96, 64)
-- One calendar day cell, square.
theme.calendar_day             = s(30, 24)

-- The lock screen's clock, set on the wallpaper as the one large thing on it.
theme.lock_clock               = s(160, 96)

-- Wider than the shared card, because the artwork sits beside the title and transport rows.
theme.media_panel_width        = s(460, 380)
theme.media_artwork            = s(96, 80)

theme.launcher_width           = s(860, 645)
theme.launcher_height          = s(680, 510)
theme.launcher_row_height      = s(64, 48)
-- Taller than an app row because the provider row carries a badge and an "Enter to copy" hint
-- beside the two text lines.
theme.launcher_special_height  = s(86, 65)
theme.launcher_icon            = s(42, 32)

-- The wallpaper picker is a fixed-width card of four columns, which size the tiles.
theme.wallpaper_picker_width   = s(1180, 900)
theme.wallpaper_picker_height  = s(880, 660)
theme.wallpaper_sidebar_width  = s(250, 200)
theme.wallpaper_columns        = 4

return theme
