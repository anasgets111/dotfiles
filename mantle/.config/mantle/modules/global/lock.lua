-- The wallpaper under a scrim, one glass card per output, and a password pill that says what PAM is
-- doing. The wallpaper is blurred at decode (`source_blur`, ADR-0240), so the scrim and card can be
-- lighter than a lock over a sharp photograph needs.
local theme         = require("config.theme")
local icons         = require("config.icons")
local util          = require("lib.util")
local wallpaper     = require("lib.wallpaper")
local cell          = require("components.cell")
local glyph         = require("components.glyph")
local panel_card    = require("components.panel_card")
local identity      = require("lib.identity")
local weather       = require("lib.weather")

local PAD           = theme.spacing.xl
-- What the card's children have to share, for the nodes that need a number rather than "Fill".
local CONTENT       = theme.lock_card_width - PAD * 2
local FIELD_HEIGHT  = theme.control.xl
-- The pill stops short of the card's own edges on both sides; using `CONTENT` makes it read as a
-- search bar rather than a card control.
local FIELD_WIDTH   = math.floor(theme.lock_card_width * 0.82)
-- Half the height, the way `theme.item_radius` is half `item_height`. `radius.xl` is the fully
-- round token, sized for the card's corner and only close to this box by coincidence.
local FIELD_RADIUS  = math.floor(FIELD_HEIGHT / 2)
local BADGE_HEIGHT  = theme.control.xs
-- Multipliers: a 68px clock, 36px initials, and a 23px name on a 1200px-tall screen. Shared steps
-- are sized for the bar, not this card.
local CLOCK_SIZE    = theme.s(72, 44)
local INITIALS_SIZE = theme.s(36, 26)
local NAME_SIZE     = theme.s(24, 18)
-- In the wallpaper's own stored pixels (its "cover" fit stores at the output's resolution), not
-- screen pixels -- exact only under that default fit (mantle ADR-0240 decision 3).
local WALLPAPER_BLUR = 24

-- The engine removes the lock after authentication, not when the tween ends, so it must be told to
-- wait out the card's exit. Read off the card's own animation rather than written twice.
local EXIT_MS       = theme.animation_slow_ms
-- Slack for the state push and first frame; without it the exit loses that round trip.
local LEAVE_SLACK   = 60
local LEAVE_MS      = EXIT_MS + LEAVE_SLACK
mantle.lock:invoke("set_unlock_animation", LEAVE_MS)

util.auto_english_layout(mantle.lock)

-- The compositor has granted the lock and PAM has not answered; both edges of the card's motion are
-- this flag. `animate.from` applies only to a node with no displayed value, and this subtree
-- outlives the lock, so entry needs the value change too.
local up           = mantle.lock:map(function(l)
    return l ~= nil and l.active and not l.unlocking
end)
-- Where the card starts its entry.
local CLOSED_SCALE = 0.94

local full_name    = identity.full_name
local account      = identity.account
local initials     = identity.initials

-- `attempts` is printed because state is sampled at layout time: two identical `error` strings
-- would otherwise look like one failure.
local hint         = util.label(mantle.lock, function(l)
    if l.error ~= nil and l.error ~= "" then
        return string.format("%s (%d)", l.error, l.attempts or 0)
    end
    if l.authenticating then
        return "Authenticating..."
    end
    if not l.active then
        return "Locking..."
    end
    return "Press Enter to unlock"
end)

local failed       = util.shown_when(mantle.lock, function(l)
    return l.error ~= nil and l.error ~= ""
end)

-- Border and hint colours change together, so failure is one state change.
local field_border = mantle.lock:map(function(l)
    if l == nil then
        return theme.GLASS_BORDER
    end
    if l.error ~= nil and l.error ~= "" then
        return theme.RED
    end
    return l.authenticating and theme.ACCENT or theme.GLASS_BORDER
end)

local caps         = mantle.keyboard:map(function(k)
    return k ~= nil and k.caps_lock == true
end)

-- Black on yellow, chosen by the same helper the bar's buttons use.
local BADGE_FG     = theme.text_contrast(theme.YELLOW)

-- One icon-and-reading pair from the divider row. Three literal children need no `list`.
local function status_item(icon_glyph, label, visible)
    return row {
        spacing = theme.spacing.xs,
        visible = visible,
        children = {
            glyph(icon_glyph, theme.with_opacity(theme.ACCENT, 0.6), theme.icon.sm, { align_v = "Center" }),
            cell(label, theme.DIM, theme.font.sm, { align_v = "Center" }),
        },
    }
end

-- Built per output because the compositor calls `child` for each lock surface. Each surface owns
-- its wallpaper and field. The field is on every output, so the compositor can focus the sole
-- `secure_submit` field on whichever screen has keyboard focus.
local function content(output)
    -- `secure_submit` keeps keystrokes in a native buffer on the Renderer's Wayland thread; they
    -- leave as a `("lock", "authenticate")` envelope, never a Lua value. No `on_change`/`on_submit`:
    -- either would reopen that path. As the surface's only such field it is armed on compositor
    -- focus, so unlocking needs no click.
    local password_field = textfield {
        width = "Fill",
        height = FIELD_HEIGHT,
        placeholder = "Password",
        mask_character = "*",
        secure_submit = { capability = "lock", action = "authenticate" },
        font_size = theme.font.lg,
        foreground = theme.with_opacity(theme.FG, 0.7),
        align_v = "Center",
    }

    local card = panel_card({
        column {
            width = "Fill",
            spacing = theme.spacing.xs,
            children = {
                -- Build the 12-hour clock from `os.date("*t")` rather than `%I` (which pads to
                -- "01:40") or `%p` (which follows the locale).
                cell(util.label(mantle.system, function(s)
                    local t = os.date("*t", s.time)
                    local hour = t.hour % 12
                    return {
                        {
                            text = string.format("%d:%02d %s", hour == 0 and 12 or hour, t.min,
                                t.hour < 12 and "AM" or "PM"),
                            bold = true,
                        },
                    }
                end), theme.FG, CLOCK_SIZE, { width = "Fill", align = "Center" }),
                -- Build the day in two calls. `%-d` is glibc-specific, and Lua rejected it before
                -- strftime saw it, returning `util.label`'s "!".
                cell(util.label(mantle.system, function(s)
                    return string.format("%s %d", os.date("%A, %B", s.time), os.date("*t", s.time).day)
                end), theme.DIM, theme.font.lg, { width = "Fill", align = "Center" }),
            },
        },
        column {
            width = "Fill",
            spacing = theme.spacing.md,
            children = {
                -- One disc: two hard circles read as a button with a focus outline.
                rect {
                    width = theme.lock_avatar,
                    height = theme.lock_avatar,
                    radius = math.floor(theme.lock_avatar / 2),
                    align_h = "Center",
                    background = theme.ACCENT_LIGHT,
                    border_width = theme.border_width,
                    border_color = theme.with_opacity(theme.ACCENT, 0.45),
                    children = {
                        cell(initials, theme.FG, INITIALS_SIZE, {
                            width = "Fill",
                            align = "Center",
                            align_v = "Center",
                        }),
                    },
                },
                -- Its own column: the account sits tighter under the name than the name under the disc.
                column {
                    width = "Fill",
                    spacing = theme.spacing.sm,
                    children = {
                        cell(full_name, theme.FG, NAME_SIZE, { width = "Fill", align = "Center" }),
                        cell(account, theme.with_opacity(theme.FG, 0.55), theme.font.sm, {
                            width = "Fill",
                            align = "Center",
                        }),
                    },
                },
            },
        },
        column {
            width = "Fill",
            spacing = theme.spacing.md,
            children = {
                row {
                    width = FIELD_WIDTH,
                    height = FIELD_HEIGHT,
                    align_h = "Center",
                    padding = { right = theme.spacing.md, left = theme.spacing.md },
                    spacing = theme.spacing.sm,
                    -- A well, not a raised control: `GLASS_CONTROL` made it the lightest thing here.
                    background = theme.GLASS,
                    radius = FIELD_RADIUS,
                    border_width = theme.border_width_medium,
                    border_color = field_border,
                    animate = { border_color = theme.animation_ms },
                    children = {
                        glyph(icons.lock, theme.with_opacity(theme.ACCENT, 0.8), theme.icon.md, {
                            align_v = "Center",
                        }),
                        password_field,
                        -- Inside the pill; the bar's indicator is across the screen.
                        row {
                            height = BADGE_HEIGHT,
                            align_v = "Center",
                            padding = { right = theme.spacing.sm, left = theme.spacing.sm },
                            spacing = theme.spacing.xs,
                            background = theme.YELLOW,
                            radius = math.floor(BADGE_HEIGHT / 2),
                            visible = caps,
                            children = {
                                glyph(icons.caps_lock, BADGE_FG, theme.icon.xs, { align_v = "Center" }),
                                cell("Caps lock", BADGE_FG, theme.font.xs, { align_v = "Center" }),
                            },
                        },
                    },
                },
                -- Wrap: "could not start authentication: pam worker failed" once clipped mid-word.
                cell(hint, failed:map(function(f)
                    return f and theme.RED or theme.with_opacity(theme.FG, 0.5)
                end), theme.font.sm, { width = "Fill", align = "Center", wrap = "Word", max_lines = 4 }),
            },
        },
        column {
            width = "Fill",
            spacing = theme.spacing.md,
            children = {
                -- Not `theme.BORDER`: surface2 at 0.75 disappears between these greys.
                rect {
                    width = math.floor(CONTENT * 0.6),
                    height = theme.border_width,
                    align_h = "Center",
                    background = theme.with_opacity(theme.FG, 0.15),
                },
                row {
                    width = "Fill",
                    align_h = "Center",
                    spacing = theme.spacing.lg,
                    children = {
                        status_item(
                            weather.code:map(weather.glyph),
                            -- Gated on the code: zero degrees is a real reading.
                            computed({ weather.code, weather.temperature }, function(code, celsius)
                                return (code or -1) >= 0 and string.format("%d°C", celsius or 0) or "--"
                            end)
                        ),
                        status_item(
                            mantle.battery:map(util.battery_glyph),
                            util.label(mantle.battery, function(b)
                                return string.format("%d%%", b.percent)
                            end),
                            util.shown_when(mantle.battery, function(b)
                                return b.present
                            end)
                        ),
                        status_item(
                            mantle.network:map(util.network_glyph),
                            util.label(mantle.network, function(n)
                                return n.ssid or "Offline"
                            end)
                        ),
                        status_item(icons.keyboard, util.label(mantle.keyboard, function(k)
                            return k.active_layout ~= "" and k.active_layout or "N/A"
                        end)),
                    },
                },
            },
        },
    }, {
        width = theme.lock_card_width,
        align_h = "Center",
        align_v = "Center",
        padding = PAD,
        -- One gap between the four groups; each pairs its own rows more tightly.
        spacing = theme.spacing.xl,
        -- Lighter than `theme.GLASS_CONTENT` (0.46), which is sized for a sharp photograph.
        background = theme.with_opacity(theme.ELEVATED, 0.3),
        radius = theme.radius.xl,
        -- With no shadow node, the edge is the only thing separating the card from the picture.
        border_width = theme.border_width_medium,
        border_color = theme.GLASS_BORDER,
    })

    return rect {
        width = "Fill",
        height = "Fill",
        -- Opaque through the exit: `ext_session_lock_v1` hides every client and niri paints solid
        -- red underneath, which a fade would reveal during `LEAVE_SLACK`.
        background = theme.BG,
        children = {
            image {
                source = wallpaper.path_of(output),
                fit = wallpaper.fit_of(output),
                width = "Fill",
                height = "Fill",
                source_blur = WALLPAPER_BLUR,
                -- The blur pass costs real time, so it stays off the frame that maps this
                -- surface; `theme.BG` covers the gap until it lands.
                async = true,
            },
            rect { width = "Fill", height = "Fill", background = theme.SCRIM },
            -- Screen-sized, so the scale pivots on the centre.
            column {
                width = "Fill",
                height = "Fill",
                align_h = "Center",
                align_v = "Center",
                -- Both need targets; an absent property skips the entry entirely.
                opacity = up:map(function(on)
                    return on and 1 or 0
                end),
                scale = up:map(function(on)
                    return on and 1 or CLOSED_SCALE
                end),
                animate = {
                    opacity = { duration = theme.animation_slow_ms, easing = "OutCubic", from = 0 },
                    scale = { duration = theme.animation_very_slow_ms, easing = "OutBack", from = CLOSED_SCALE },
                },
                children = { card },
            },
        },
    }
end

-- Declared, not open: no Wayland object exists until `mantle.lock:invoke("lock")`, and then the
-- compositor creates one surface per output.
return lock {
    id = "lock_screen",
    child = content,
}
