-- Catppuccin Mocha. An invented palette would be a worse version of one already balanced.
-- Shared tokens live here because every `shell.lua` module reads them and no module owns them.
-- The module cache clears before each re-evaluation, so edits recolour the bar in place.
local theme = {}

-- The responsive scale: `s(base)` scales non-colour tokens from 1080p values, read once during
-- evaluation from the first output. `mantle.screens` is the only signal available then; every other
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

-- `min` is a small-screen floor, not a default: a 10px label at 0.75 is 8px and legible; an 8px
-- icon becomes an illegible 6px smudge.
function theme.s(base, min)
    return math.max(min or 0, math.floor(base * SCALE + 0.5))
end

local s = theme.s

-- Colour helpers speak the engine's `#RRGGBB`/`#RRGGBBAA` strings, so results feed `background`.

local function channels(hex)
    local digits = hex:gsub("^#", "")
    return tonumber(digits:sub(1, 2), 16) or 0, tonumber(digits:sub(3, 4), 16) or 0, tonumber(digits:sub(5, 6), 16) or 0
end

-- Missing alpha means opaque; `#RRGGBB` is legal and half the palette uses it.
local function alpha_of(hex)
    local digits = hex:gsub("^#", "")
    return (tonumber(digits:sub(7, 8), 16) or 255) / 255
end

-- Replaces rather than multiplies alpha; otherwise
-- `with_opacity(BG_SUBTLE, 0.5)` would differ from `with_opacity(BG, 0.5)`.
function theme.with_opacity(hex, alpha)
    local r, g, b = channels(hex)
    return string.format("#%02x%02x%02x%02x", r, g, b, math.floor(math.max(0, math.min(1, alpha)) * 255 + 0.5))
end

-- Linear blend toward white, the `Qt.lighter` equivalent used by two elevated-surface call sites;
-- HSV is unnecessary for these small steps above `BG`.
local function lighten(hex, amount)
    local r, g, b = channels(hex)
    local mix = function(c)
        return math.floor(c + (255 - c) * amount + 0.5)
    end
    return string.format("#%02x%02x%02xff", mix(r), mix(g), mix(b))
end

-- WCAG relative luminance at the 0.179 threshold, compositing translucent colours over `BG` first:
-- the swatch alone reads light-purple `ON_HOVER` at 45% as bright, when it reaches the screen dark.
function theme.text_contrast(hex)
    local function linear(byte)
        local c = byte / 255
        if c <= 0.04045 then
            return c / 12.92
        end
        return ((c + 0.055) / 1.055) ^ 2.4
    end
    local r, g, b = channels(hex)
    local mix = alpha_of(hex)
    if mix < 1 then
        local gr, gg, gb = channels(theme.BG)
        r, g, b = r * mix + gr * (1 - mix), g * mix + gg * (1 - mix), b * mix + gb * (1 - mix)
    end
    local luminance = 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    return luminance > 0.179 and "#000000ff" or "#ffffffff"
end

-- `opacity` multiplies down the subtree, so dimming a control is one property, not a colour per part.
theme.opacity                   = {
    subtle   = 0.15,
    light    = 0.25,
    medium   = 0.35,
    disabled = 0.5,
    muted    = 0.7,
    strong   = 0.8,
    full     = 0.95,
}

-- The eleven swatches everything else derives from.
theme.BG                        = "#1e1e2eff"
theme.SURFACE                   = "#313244ff"
-- Catppuccin surface1, one step above SURFACE; pointer highlights use it instead of inventing blue.
theme.HOVER                     = "#45475aff"
theme.FG                        = "#cdd6f4ff"
-- Catppuccin subtext0; overlay0 reads as disabled rather than secondary. The one secondary-text
-- colour -- faded controls use node `opacity`.
theme.DIM                       = "#a6adc8ff"
-- Mauve, not blue; `MAUVE` is the same swatch under its colour name.
theme.ACCENT                    = "#cba6f7ff"
theme.GREEN                     = "#a6e3a1ff"
theme.YELLOW                    = "#f9e2afff"
theme.PEACH                     = "#fab387ff"
theme.RED                       = "#f38ba8ff"
theme.MAUVE                     = "#cba6f7ff"
-- Catppuccin blue; two modules need blue specifically.
theme.BLUE                      = "#89b4faff"
-- `INACTIVE` and `ON_HOVER`, passed to `with_opacity`, not painted directly.
theme.INACTIVE                  = "#494d64ff"
theme.ON_HOVER                  = "#a28dcdff"
theme.DISABLED                  = "#232634ff"

-- Derived steps from the eleven swatches, so a scheme swap remains eleven edits.
theme.ELEVATED                  = lighten(theme.BG, 0.12)
theme.ELEVATED_HOVER            = lighten(theme.BG, 0.18)
-- `TEXT_OFF`: dimmer than DIM but unused: this config has no disabled toggle.
theme.TEXT_OFF                  = theme.with_opacity(theme.DIM, theme.opacity.medium)
theme.BORDER                    = theme.with_opacity(theme.SURFACE, 0.75)
theme.BORDER_SUBTLE             = theme.with_opacity(theme.SURFACE, 0.35)
-- The shared card ground, so a card reads as a sheet above the bar rather than the same tone.
theme.GLASS                     = theme.with_opacity("#181825", 0.88)
theme.GLASS_CONTENT             = theme.with_opacity(theme.ELEVATED, 0.46)
-- `GLASS_INPUT`: a text field sits on the base tone, not the elevated one, so a search box reads
-- as a well cut into the card it shares an edge with rather than a second card.
theme.GLASS_INPUT               = theme.with_opacity(theme.BG, 0.62)
theme.GLASS_HOVER               = theme.with_opacity(theme.ELEVATED_HOVER, 0.62)
theme.ACCENT_SUBTLE             = theme.with_opacity(theme.ACCENT, theme.opacity.subtle)
theme.ACCENT_LIGHT              = theme.with_opacity(theme.ACCENT, theme.opacity.light)
theme.ACCENT_MEDIUM             = theme.with_opacity(theme.ACCENT, theme.opacity.medium)
-- Hover for an opaque `ACCENT` ground. The three alpha tints cannot lift an opaque colour, so it
-- is lightened instead.
theme.ACCENT_HOVER              = lighten(theme.ACCENT, 0.16)
-- The same lift for the one opaque `RED` ground: the stop button, which gets the same primary
-- hover as accent.
theme.RED_HOVER                 = lighten(theme.RED, 0.16)
-- Ink for text on a glass control under the pointer, lifted the same 0.16 as the two grounds
-- above. Panel headers rest at `FG` and reach this on hover; `ACCENT` marks the open state.
theme.TEXT_ACTIVE               = lighten(theme.FG, 0.16)
-- Used as the plate behind a notification card's application icon.
theme.BG_SUBTLE                 = theme.with_opacity(theme.BG, theme.opacity.subtle)

-- The chrome is translucent throughout: opaque controls turn floating pills into filled rectangles,
-- and radius cannot fix it. Alpha reaches the compositor, so the layer composites against wallpaper.
theme.GLASS_SURFACE             = theme.with_opacity(theme.BG, 0.5)
theme.GLASS_CONTROL             = theme.with_opacity(theme.INACTIVE, 0.42)
theme.TOOLTIP_FG               = theme.text_contrast(theme.GLASS_SURFACE)
-- 0.45, not 0.68: on a glass control over wallpaper, 0.68 makes hover the bar's
-- brightest element. 0.45 keeps the glyph white instead of inverting it.
theme.GLASS_CONTROL_HOVER       = theme.with_opacity(theme.ON_HOVER, 0.45)
theme.GLASS_BORDER              = theme.with_opacity(theme.FG, 0.18)
theme.GLASS_BORDER_HOVER        = theme.with_opacity(theme.FG, 0.34)
theme.ALERT_BG                  = "#45253aff"
-- `SCRIM` is 0.45 rather than 0.88: it lays over wallpaper, where 0.88 is a blackout.
theme.SCRIM                     = theme.with_opacity(theme.BG, 0.45)

-- Named steps keep `spacing.sm` the same in bar and panel, and let one edit change both.
theme.spacing                   = {
    xs = s(4, 2),
    sm = s(8, 4),
    md = s(12, 8),
    lg = s(16, 10),
    xl = s(24, 16),
}

-- Named on every icon node: `Mono` keeps an indicator to one cell, unlike the `Propo` body face.
theme.icon_font                 = "JetBrainsMono Nerd Font Mono"
-- Command output, so columns in a log line up.
theme.mono_font                 = theme.icon_font

theme.font                      = {
    xs   = s(10, 8),
    sm   = s(12, 10),
    md   = s(14, 12),
    lg   = s(16, 14),
    xl   = s(20, 16),
    xxl  = s(28, 20),
    hero = s(48, 32),
}

theme.radius                    = {
    sm = s(6, 4),
    md = s(12, 8),
    lg = s(18, 12),
    xl = s(40, 20),
}

theme.icon                      = {
    xs = s(12, 10),
    sm = s(14, 12),
    md = s(18, 14),
    lg = s(24, 18),
    xl = s(32, 24),
}

-- Keeps adjacent toggles and buttons aligned without pixel literals.
theme.control                   = {
    xs = s(24, 20),
    sm = s(28, 24),
    md = s(34, 28),
    lg = s(42, 34),
    xl = s(52, 42),
}
theme.control_width_lg           = s(48, 40)
theme.card_padding               = s(10, 8)

theme.border_width              = 1
-- `border_width_medium`: twice the hairline, for cards floating over wallpaper.
theme.border_width_medium       = 2

-- Surface geometry, shared so a module and its opener cannot disagree.
theme.bar_height                = s(42, 28)
theme.panel_toggle_compact_threshold = s(220)

-- `control` sizes panel contents, `item` sizes bar controls. `item_radius` is half `item_height`
-- with its own `s()`, since rounding it separately keeps a circle from a round square.
--
-- `title_limit` is a character budget, not a box: the centre zone stays content-sized so its
-- midpoint is the bar's.
theme.title_limit               = (MAIN_WIDTH / math.max(1, MAIN_HEIGHT)) > 2.1 and 74 or 47

-- A third of the screen while media is up, so the spectrum has a span to fill.
theme.center_zone_width         = math.floor(MAIN_WIDTH / 3)

theme.item_height               = s(34, 20)
theme.item_width                = s(34, 20)
theme.item_radius               = s(18, 6)
-- Enough for a glyph and "100%"; the bar's non-circular item.
theme.battery_pill_width        = s(80, 60)
-- Hovered volume control: holds "150%" plus a drag track.
theme.volume_expanded_width     = s(220, 140)
-- Milliseconds for a node's `animate` table; the engine eases `InOutQuad` by default.
theme.animation_ms              = 147
theme.animation_fast_ms         = 100
-- A pulse rather than a transition: slow enough to read as breathing.
theme.animation_slow_ms         = 250
theme.animation_very_slow_ms    = 400
-- Notification travel, derived so it follows the base rather than pinning 206.
theme.notification_slide_ms     = math.floor(theme.animation_ms * 1.4 + 0.5)
-- For a fill being scrubbed by key repeat: an eased tween restarts from a standstill on every
-- retarget and falls behind, where a spring carries its velocity across. 400/42 is critically
-- damped, and a single press still lands in about a tenth of a second.
theme.spring_tracking           = { spring = { stiffness = 400, damping = 42 } }
-- Bar panels share one card in `modules/shell/panel_host.lua`; each list holds seven rows, then scrolls.
theme.panel_width               = s(340, 280)
theme.panel_list_height         = s(280, 210)
-- Where a closed panel sits before `geometry` has measured it; after that it uses `-height`.
theme.panel_slide               = s(760, 570)
-- History holds the popup's cards plus the weather and sysinfo widgets.
theme.notification_panel_width  = s(460, 380)
theme.notification_list_height  = s(640, 480)
-- A name and two version columns: 460px still elided `gpu-screen-recorder-git`.
theme.update_panel_width        = s(520, 400)

-- Two named sliders and a mixer.
theme.audio_panel_width         = s(380, 300)

-- An application's own words need more room than the shell's: the 340px card elides
-- "Preferences and settings".
theme.tray_menu_width           = s(300, 240)
-- Idle modal: action rows plus AC and battery columns, each with a timeout and switch, at 820px.
theme.idle_modal_width          = s(820, 640)
-- `idle_profile_column` plus its switch.
theme.idle_profile_column       = s(190, 150)
theme.idle_row_height           = s(60, 46)
-- Timeline track, wide as the card and tall enough for a glyph plus duration per stage, unlike the
-- 6px `components/meter.lua` percentage meter.
theme.idle_track_height         = s(36, 28)
theme.update_list_height        = s(360, 260)
-- Fixed, so versions align down the table; wide enough for `6.1.0.r4.gc8f50c4-1`.
theme.update_version_width      = s(116, 88)
-- Keep the log shorter than the package list; its last dozen lines explain a failure.
theme.update_log_height         = s(200, 150)
-- Rescue modal: a traceback's paths wrap at 520px, and its log scrolls rather than fills the screen.
theme.rescue_modal_width        = s(720, 560)
theme.rescue_log_height         = s(320, 240)
-- `panel_toggle_height`: a radio tile tall enough for a glyph over a word.
theme.panel_toggle_height       = s(56, 44)
-- `components/panel_empty_state.lua`'s minimum height: an empty list holds a glyph and line,
-- reading as a state rather than a gap.
theme.panel_empty_height        = s(120, 90)
theme.panel_gap                 = 4
theme.notification_width        = s(380, 300)
-- `notification_app_icon`: an `item_height` icon square with a few pixels of plate around it.
theme.notification_app_icon     = s(40, 32)
-- The stack surface, not a card: generous, because the fixed layer clips what four expanded cards
-- overflow, and the inner column sizes to content.
theme.notification_stack_height = s(560, 420)
-- Fixed: a glyph, a bar and a percentage never change length, and a card resizing under a held
-- volume key would be the only thing moving on screen.
theme.osd_width                 = s(300, 240)
-- The toggle layout has no bar and holds whatever the system said, so it is content-sized; this
-- floor keeps "num lock on" from drawing a card as narrow as the words.
theme.osd_toggle_min            = s(220, 176)
theme.osd_height                = s(80, 60)
theme.osd_tile                  = s(48, 36)
theme.osd_track                 = s(12, 8)
-- `dialog_width`: the polkit card (`modules/global/polkit.lua`), narrower than the launcher because
-- it holds one sentence, one field and two buttons.
theme.dialog_width              = s(450, 360)

-- The lock card is landscape, so it is the one token measured from screen width: 38% clamped to
-- 480..720, where a height-scaled `s(480)` would be narrower than it is tall.
theme.lock_card_width           = math.max(480, math.min(math.floor(MAIN_WIDTH * 0.38), 720))
-- `control.lg * 2.4`, the initials disc, measured at 106px on a 1200px-tall screen.
theme.lock_avatar               = s(112, 72)

-- Wider than the shared card: the artwork sits beside the title and transport rows, not above them.
theme.media_panel_width         = s(460, 380)
theme.media_artwork             = s(96, 80)

-- The launcher (`modules/global/launcher.lua`).
theme.launcher_width            = s(860, 645)
theme.launcher_height           = s(680, 510)
theme.launcher_row_height       = s(64, 48)
-- Taller than an app row because the provider row carries a badge and an "Enter to copy" hint
-- beside the two text lines.
theme.launcher_special_height   = s(86, 65)
theme.launcher_icon             = s(42, 32)

-- The wallpaper picker: a fixed-width card of four columns, which size the tiles.
theme.wallpaper_picker_width    = s(1180, 900)
theme.wallpaper_picker_height   = s(880, 660)
theme.wallpaper_sidebar_width   = s(250, 200)
theme.wallpaper_columns         = 4

return theme
