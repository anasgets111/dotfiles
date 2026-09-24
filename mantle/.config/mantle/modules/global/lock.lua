-- The wallpaper under a scrim, the time set large on it, one glass card per output holding who is
-- locked and a password pill that says what PAM is doing, and the status readings along the bottom.
-- The scrim frosts the wallpaper (`backdrop_blur`), so the scrim and card can be lighter than a lock
-- over a sharp photograph needs.
local theme          = require("config.theme")
local icons          = require("config.icons")
local util           = require("lib.util")
local wallpaper      = require("lib.wallpaper")
local cell           = require("components.cell")
local glyph          = require("components.glyph")
local panel_card     = require("components.panel_card")
local callout        = require("components.callout")
local info_badge     = require("components.info_badge")
local identity       = require("lib.identity")
local weather        = require("lib.weather")

local PAD            = theme.spacing.xl
local FIELD_HEIGHT   = theme.control.xl
-- Half the height, the way `theme.item_radius` is half `item_height`. `radius.xl` is the fully
-- round token, sized for the card's corner and only close to this box by coincidence.
local FIELD_RADIUS   = math.floor(FIELD_HEIGHT / 2)
-- The disc matches the pill below it, so the card's two rows share one height.
local AVATAR         = FIELD_HEIGHT
local WALLPAPER_BLUR = 24
-- A second frost under the card, over the already-blurred wallpaper, so the glass reads thicker
-- than the ground around it.
local CARD_BLUR      = 16
-- Between the clock, the card and the status row arriving, so the eye lands on the time first.
local STAGGER        = 90
-- A wrong password shakes the pill left and right, damping out.
local SHAKE          = {
    duration = 60,
    easing = "InOutQuad",
    keyframes = { { x = 0 }, { x = -10 }, { x = 10 }, { x = -6 }, { x = 6 }, { x = -2 }, { x = 0 } },
}

-- The engine removes the lock after authentication, not when the tween ends, so it must be told to
-- wait out the card's exit plus slack for the state push and first frame.
local LEAVE_SLACK    = 60
mantle.lock:set_unlock_animation(theme.animation_slow_ms + LEAVE_SLACK)

util.auto_english_layout(mantle.lock)

-- The compositor has granted the lock and PAM has not answered; both edges of the card's motion are
-- this flag. `animate.from` applies only to a node with no displayed value, and this subtree
-- outlives the lock, so entry needs the value change too.
local up           = mantle.lock:map(function(lock)
    return lock ~= nil and lock.active and not lock.unlocking
end)
-- Where the card starts its entry.
local CLOSED_SCALE = 0.94

-- `props` fading and sliding in from `offset` px, `order` steps after the lock is granted. Exit drops
-- the delay, so everything leaves inside the engine's unlock window. `scale` grows it from
-- `CLOSED_SCALE` too; both edges need a target, since an absent property skips the entry.
local function entering(props, order, offset, scale)
    props.opacity = up:map(function(on)
        return on and 1 or 0
    end)
    props.translate = up:map(function(on)
        return { y = on and 0 or offset }
    end)
    props.scale = scale and up:map(function(on)
        return on and 1 or CLOSED_SCALE
    end) or nil
    props.animate = up:map(function(on)
        local delay = on and order * STAGGER or 0
        return {
            opacity = { duration = theme.animation_slow_ms, easing = "OutCubic", delay = delay, from = 0 },
            translate = { duration = theme.animation_very_slow_ms, easing = "OutCubic", delay = delay, from = { y = offset } },
            scale = scale and
                { duration = theme.animation_very_slow_ms, easing = "OutCubic", delay = delay, from = CLOSED_SCALE } or
                nil,
        }
    end)
    return props
end

local hint         = util.label(mantle.lock, function(lock)
    if lock.authenticating then
        return "Authenticating…"
    end
    if not lock.active then
        return "Locking…"
    end
    return "Press Enter to unlock"
end)

local failed       = util.shown_when(mantle.lock, function(lock)
    return lock.error ~= nil and lock.error ~= ""
end)

-- Border and hint colours change together, so failure is one state change.
local field_border = computed({ failed, mantle.lock }, function(error_shown, lock)
    if error_shown then
        return theme.RED
    end
    return lock ~= nil and lock.authenticating and theme.ACCENT or theme.GLASS_BORDER
end)

-- `attempts` is printed because state is sampled at layout time: two identical `error` strings
-- would otherwise look like one failure.
local error_text   = util.label(mantle.lock, function(lock)
    return string.format("%s (%d)", lock.error, lock.attempts or 0)
end)

-- Each new failure replays the shake; `failed` keeps a reset count at lock start from playing it.
local shaking      = computed({ pulse(mantle.lock:map(function(lock)
    return lock and lock.attempts or 0
end), SHAKE.duration * #SHAKE.keyframes), failed }, function(fresh, error_shown)
    return fresh and error_shown
end)

-- One icon-and-reading pair from the status row. Three literal children need no `list`.
local function status_item(icon_glyph, label, visible)
    return row {
        spacing = theme.spacing.xs,
        visible = visible,
        children = {
            glyph(icon_glyph, theme.ACCENT, theme.icon.md, { align_v = "Center" }),
            cell(label, theme.FG, theme.font.md, { align_v = "Center" }),
        },
    }
end

-- Hours bold and minutes regular in one run pair. No meridiem: beside numerals this size it floated
-- off their baseline, and a lock screen is read at a glance.
local clock = mantle.system:map(function(system)
    local now = os.date("*t", system and system.time)
    local hour = now.hour % 12
    return {
        { text = tostring(hour == 0 and 12 or hour), bold = true },
        { text = string.format(":%02d", now.min) },
    }
end)

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
        mask_character = "•",
        secure_submit = { capability = "lock", action = "authenticate" },
        font_size = theme.font.lg,
        foreground = theme.FG,
        align_v = "Center",
    }

    -- Build the 12-hour clock from `os.date("*t")` rather than `%I`, which pads to "01:40". Build the day in two calls: `%-d` is glibc-specific, and Lua
    -- rejected it before strftime saw it, returning `util.label`'s "!".
    local time = column(entering({
        align_h = "Center",
        spacing = theme.spacing.xs,
        children = {
            cell(clock, theme.FG, theme.lock_clock, { align = "Center" }),
            cell(util.label(mantle.system, function(system)
                return string.format("%s %d", os.date("%A, %B", system.time), os.date("*t", system.time).day)
            end), theme.DIM, theme.font.xl, { align = "Center" }),
        },
    }, 0, -theme.spacing.md))

    local card = panel_card({
        row {
            width = "Fill",
            spacing = theme.spacing.md,
            children = {
                -- One disc: two hard circles read as a button with a focus outline.
                rect {
                    width = AVATAR,
                    height = AVATAR,
                    radius = math.floor(AVATAR / 2),
                    background = theme.ACCENT_LIGHT,
                    border_width = theme.border_width,
                    border_color = theme.with_opacity(theme.ACCENT, 0.45),
                    children = {
                        cell(util.bold(identity.initials), theme.FG, theme.font.lg, {
                            width = "Fill",
                            align = "Center",
                            align_v = "Center",
                        }),
                    },
                },
                column {
                    width = "Fill",
                    align_v = "Center",
                    spacing = theme.spacing.xs,
                    children = {
                        cell(util.bold(identity.full_name), theme.FG, theme.font.xl, { width = "Fill" }),
                        cell(identity.account, theme.DIM, theme.font.sm, { width = "Fill" }),
                    },
                },
            },
        },
        row {
            width = "Fill",
            height = FIELD_HEIGHT,
            padding = { right = theme.spacing.md, left = theme.spacing.md },
            spacing = theme.spacing.sm,
            -- A well, not a raised control: `GLASS_CONTROL` made it the lightest thing here, and
            -- `GLASS` a black bar on the frosted card.
            background = theme.GLASS_INPUT,
            radius = FIELD_RADIUS,
            border_width = theme.border_width_medium,
            border_color = field_border,
            translate = { x = 0, y = 0 },
            animate = shaking:map(function(on)
                return { border_color = theme.animation_ms, translate = on and SHAKE or nil }
            end),
            children = {
                glyph(icons.lock, theme.with_opacity(theme.ACCENT, 0.8), theme.icon.md, {
                    align_v = "Center",
                }),
                password_field,
                -- Inside the pill; the bar's indicator is across the screen.
                info_badge("Caps lock", theme.YELLOW, {
                    visible = util.shown_when(mantle.keyboard, function(keyboard)
                        return keyboard.caps_lock == true
                    end),
                }),
            },
        },
        -- Round like the pill above it; the panels' `radius.sm` read as a stray box here.
        callout(icons.warning, error_text, { visible = failed, radius = theme.radius.xl }),
        cell(hint, theme.TEXT_MUTED, theme.font.sm, {
            width = "Fill",
            align = "Center",
            visible = failed:map(function(error_shown)
                return not error_shown
            end),
        }),
    }, {
        width = theme.dialog_width,
        align_h = "Center",
        padding = PAD,
        spacing = theme.spacing.lg,
        -- Lighter than `theme.GLASS_CONTENT` (0.46), which is sized for a sharp photograph.
        background = theme.with_opacity(theme.ELEVATED, 0.3),
        radius = theme.radius.xl,
        backdrop_blur = CARD_BLUR,
        -- With no shadow node, the edge is the only thing separating the card from the picture.
        border_width = theme.border_width_medium,
        border_color = theme.GLASS_BORDER,
    })

    -- Context, not a control, so it sits on the wallpaper at the bottom edge.
    local status = row(entering({
        align_h = "Center",
        align_v = "End",
        margin = { bottom = theme.spacing.xl * 2 },
        spacing = theme.spacing.xl,
        children = {
            status_item(
                weather.code:map(weather.glyph),
                weather.temperature:map(function(celsius)
                    return string.format("%d°C", celsius or 0)
                end),
                -- Gated on the code: zero degrees is a real reading.
                weather.code:map(function(code)
                    return (code or -1) >= 0
                end)
            ),
            status_item(
                mantle.battery:map(util.battery_glyph),
                util.label(mantle.battery, function(battery)
                    return string.format("%d%%", battery.percent)
                end),
                util.shown_when(mantle.battery, function(battery)
                    return battery.present
                end)
            ),
            status_item(
                mantle.network:map(util.network_glyph),
                util.label(mantle.network, function(network)
                    return network.ssid or "Offline"
                end)
            ),
            status_item(
                icons.keyboard,
                util.label(mantle.keyboard, function(keyboard)
                    return keyboard.active_layout
                end),
                util.shown_when(mantle.keyboard, function(keyboard)
                    return keyboard.active_layout ~= ""
                end)
            ),
        },
    }, 2, theme.spacing.md))

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
                -- The desktop's own texture, so it draws on the first frame; unblurred, since a
                -- `source_blur` would key a second copy that decodes after the lock maps.
                async = true,
            },
            -- The desktop frosts over as the lock arrives and thaws halfway as it leaves: clearing
            -- fully under the fading card read as a glitch.
            rect {
                width = "Fill",
                height = "Fill",
                background = theme.SCRIM,
                backdrop_blur = util.lift(mantle.lock, function(lock)
                    if lock == nil or not lock.active then
                        return 0
                    end
                    return lock.unlocking and WALLPAPER_BLUR / 2 or WALLPAPER_BLUR
                end),
                animate = { backdrop_blur = { duration = theme.animation_slow_ms, easing = "OutCubic", from = 0 } },
            },
            -- Screen-sized and stacking, so each child keeps its own placement.
            rect {
                width = "Fill",
                height = "Fill",
                children = {
                    column {
                        align_h = "Center",
                        align_v = "Center",
                        spacing = theme.spacing.xl * 2,
                        children = {
                            time,
                            column(entering({ align_h = "Center", children = { card } }, 1, -theme.spacing.md, true)),
                        },
                    },
                    status,
                },
            },
        },
    }
end

-- Declared, not open: no Wayland object exists until `mantle.lock:lock()`, and then the
-- compositor creates one surface per output.
return lock {
    id = "lock_screen",
    child = content,
}
