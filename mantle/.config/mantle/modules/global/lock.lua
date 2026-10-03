-- Clock, identity, secure password field and system status over a frosted wallpaper.
local theme          = require("config.theme")
local icons          = require("config.icons")
local util           = require("lib.util")
local wallpaper      = require("lib.wallpaper")
local cell           = require("components.cell")
local glyph          = require("components.glyph")
local panel_card     = require("components.panel_card")
local icon_button    = require("components.icon_button")
local info_badge     = require("components.info_badge")
local scrim          = require("components.scrim")
local identity       = require("lib.identity")
local weather        = require("lib.weather")

local FIELD_HEIGHT   = theme.control.xl
local FIELD_RADIUS   = FIELD_HEIGHT / 2
-- Centre both controls on the pill's rounded ends.
local ICON_INSET     = (FIELD_HEIGHT - theme.icon.md) / 2
local BUTTON_INSET   = (FIELD_HEIGHT - theme.control.lg) / 2
local WALLPAPER_BLUR = 24
local CARD_BLUR      = 16
local STAGGER        = 90
-- A wrong password shakes the pill left and right, damping out.
local SHAKE          = {
    duration = 60,
    easing = "in_out_quad",
    keyframes = { { x = 0 }, { x = -10 }, { x = 10 }, { x = -6 }, { x = 6 }, { x = -2 }, { x = 0 } },
}

-- Keep the lock until the card's exit finishes, plus scheduling slack.
local LEAVE_SLACK    = 60
mantle.lock:set_unlock_animation(theme.animation_slow_ms + LEAVE_SLACK)

util.auto_english_layout(mantle.lock)

-- The subtree survives unlock; both entry and exit need an explicit target.
local up           = mantle.lock:map(function(lock)
    return lock ~= nil and lock.active and not lock.unlocking
end)
local opacity      = util.choose(up, 1, 0)
local CLOSED_SCALE = 0.94

-- Stagger entry; exit together inside the engine's unlock window.
local function entering(props, order, offset, scale)
    props.opacity = opacity
    props.translate = up:map(function(on)
        return { y = on and 0 or offset }
    end)
    props.scale = scale and util.choose(up, 1, CLOSED_SCALE) or nil
    props.animate = up:map(function(on)
        local delay = on and order * STAGGER or 0
        return {
            opacity = { duration = theme.animation_slow_ms, easing = "out_cubic", delay = delay, from = 0 },
            translate = { duration = theme.animation_very_slow_ms, easing = "out_cubic", delay = delay, from = { y = offset } },
            scale = scale and
                { duration = theme.animation_very_slow_ms, easing = "out_cubic", delay = delay, from = CLOSED_SCALE } or
                nil,
        }
    end)
    return props
end

local busy         = util.shown_when(mantle.lock, function(lock)
    return lock.authenticating or lock.unlocking
end)
local ERROR_TEXT   = {
    ["authentication failed"] = "Incorrect password. Try again.",
    ["too many attempts"] = "Too many attempts. Try again later.",
}
local feedback     = mantle.lock:map(function(lock)
    if lock == nil or not lock.active then
        return "Locking…"
    end
    if lock.unlocking then
        return "Unlocking…"
    end
    if lock.authenticating then
        return "Checking…"
    end
    local error = lock.error or ""
    return ERROR_TEXT[error] or (error ~= "" and error) or "Press Enter to unlock"
end)

local failed       = util.shown_when(mantle.lock, function(lock)
    return lock.active and not lock.authenticating and not lock.unlocking and lock.error ~= nil and lock.error ~= ""
end)

local field_border = computed({ busy, failed }, function(checking, error_shown)
    return checking and theme.ACCENT or error_shown and theme.RED or theme.GLASS_BORDER
end)

-- Each new failure replays the shake; `failed` keeps a reset count at lock start from playing it.
local shaking      = computed({ pulse(mantle.lock:map(function(lock)
    return lock and lock.attempts or 0
end), SHAKE.duration * #SHAKE.keyframes), failed }, function(fresh, error_shown)
    return fresh and error_shown
end)

local function status_item(icon_glyph, label, visible)
    return row {
        spacing = theme.spacing.xs,
        visible = visible,
        children = {
            glyph(icon_glyph, theme.DIM, theme.icon.md, { align_v = "center" }),
            cell(label, theme.FG, theme.font.md, { align_v = "center" }),
        },
    }
end

-- Bold hours and regular minutes, without a leading zero.
local clock = mantle.system:map(function(system)
    local now = os.date("*t", system and system.time)
    local hour = now.hour % 12
    return {
        { text = tostring(hour == 0 and 12 or hour), bold = true },
        { text = string.format(":%02d", now.min) },
    }
end)

-- One secure field per output, armed on compositor focus.
local function content(output)
    -- Passwords stay in the native buffer. Never attach `on_change` or `on_submit`.
    local password_field = textfield {
        width = "fill",
        height = FIELD_HEIGHT,
        placeholder = "Password",
        mask_character = "•",
        secure_submit = { capability = "lock", action = "authenticate" },
        font_size = theme.font.lg,
        foreground = theme.FG,
        align_v = "center",
    }

    local unlock = icon_button(icons.chevron_right, nil, {
        slot = "lock-unlock-" .. output,
        size = theme.control.lg,
        icon_size = theme.icon.md,
        border = false,
        background = theme.GLASS_CONTROL,
        background_hover = theme.ACCENT_LIGHT,
        foreground = theme.FG,
        spinning = busy,
        cursor = util.choose(busy, "default", "pointer"),
    })
    unlock.submit = busy:map(function(checking)
        return not checking
    end)

    -- Lua rejects `%-d`; read the unpadded day from the date table.
    local time = column(entering({
        align_h = "center",
        spacing = theme.spacing.xs,
        children = {
            cell(clock, theme.FG, theme.lock_clock, { align = "center" }),
            cell(util.label(mantle.system, function(system)
                return string.format("%s %d", os.date("%A, %B", system.time), os.date("*t", system.time).day)
            end), theme.DIM, theme.font.xl, { align = "center" }),
        },
    }, 0, -theme.spacing.md))

    local card = panel_card({
        row {
            width = "fill",
            spacing = theme.spacing.md,
            children = {
                rect {
                    width = FIELD_HEIGHT,
                    height = FIELD_HEIGHT,
                    radius = FIELD_RADIUS,
                    background = theme.GLASS_CONTROL,
                    children = {
                        cell(util.bold(identity.initials), theme.FG, theme.font.lg, {
                            width = "fill",
                            align = "center",
                            align_v = "center",
                        }),
                    },
                },
                column {
                    width = "fill",
                    align_v = "center",
                    spacing = theme.spacing.xs,
                    children = {
                        cell(util.bold(identity.full_name), theme.FG, theme.font.xl, { width = "fill" }),
                        cell(identity.account, theme.DIM, theme.font.sm, { width = "fill" }),
                    },
                },
            },
        },
        row {
            width = "fill",
            height = FIELD_HEIGHT,
            padding = { right = BUTTON_INSET, left = ICON_INSET },
            spacing = theme.spacing.sm,
            background = theme.GLASS_INPUT,
            radius = FIELD_RADIUS,
            border_width = theme.border_width_medium,
            border_color = field_border,
            translate = { x = 0, y = 0 },
            animate = shaking:map(function(on)
                return { border_color = theme.animation_ms, translate = on and SHAKE or nil }
            end),
            children = {
                glyph(icons.lock, theme.DIM, theme.icon.md, {
                    width = theme.icon.md,
                    align = "center",
                    align_v = "center",
                }),
                password_field,
                unlock,
            },
        },
        column {
            width = "fill",
            padding = { left = ICON_INSET, right = BUTTON_INSET },
            spacing = theme.spacing.sm,
            children = {
                row {
                    width = "fill",
                    height = theme.control.xs,
                    align_v = "center",
                    spacing = theme.spacing.sm,
                    children = {
                        glyph(icons.keyboard, theme.DIM, theme.icon.sm, {
                            width = theme.icon.md, align = "center", align_v = "center",
                        }),
                        cell(util.label(mantle.keyboard, function(keyboard)
                            return keyboard.active_layout
                        end), theme.DIM, theme.font.md, { width = "fill", align_v = "center" }),
                        info_badge("Caps lock", theme.YELLOW, {
                            visible = util.shown_when(mantle.keyboard, function(keyboard)
                                return keyboard.caps_lock == true
                            end),
                        }),
                    },
                },
                -- Both lines stay reserved, so an error or Caps Lock never moves the input.
                rect {
                    width = "fill",
                    height = theme.control.lg,
                    padding = { left = theme.icon.md + theme.spacing.sm },
                    children = { cell(feedback, util.choose(failed, theme.RED, theme.DIM), theme.font.lg, {
                        width = "fill", align = "start", align_v = "start", wrap = "word", max_lines = 2,
                    }) },
                },
            },
        },
    }, {
        width = theme.dialog_width,
        align_h = "center",
        padding = theme.spacing.xl,
        spacing = theme.spacing.lg,
        background = theme.with_opacity(theme.ELEVATED, 0.3),
        glass = true,
        radius = theme.radius.xl,
        backdrop_blur = CARD_BLUR,
    })

    -- Context, not a control, so it sits on the wallpaper at the bottom edge.
    local status = row(entering({
        align_h = "center",
        align_v = "end",
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
        },
    }, 2, theme.spacing.md))

    return rect {
        width = "fill",
        height = "fill",
        -- Opaque through the exit: `ext_session_lock_v1` hides every client and niri paints solid
        -- red underneath, which a fade would reveal during `LEAVE_SLACK`.
        background = theme.BG,
        children = {
            image {
                source = wallpaper.path_of(output),
                fit = wallpaper.fit_of(output),
                width = "fill",
                height = "fill",
                -- Reuse the desktop texture; `source_blur` would decode a second copy.
                async = true,
            },
            -- Thaw halfway on exit to avoid a sharp flash under the fading card.
            scrim(nil, {
                backdrop_blur = util.lift(mantle.lock, function(lock)
                    if lock == nil or not lock.active then
                        return 0
                    end
                    return lock.unlocking and WALLPAPER_BLUR / 2 or WALLPAPER_BLUR
                end),
                animate = { backdrop_blur = { duration = theme.animation_slow_ms, easing = "out_cubic", from = 0 } },
            }),
            column {
                align_h = "center",
                align_v = "center",
                spacing = theme.spacing.xl * 2,
                children = {
                    time,
                    column(entering({ align_h = "center", children = { card } }, 1, -theme.spacing.md, true)),
                },
            },
            status,
        },
    }
end

-- Declared, not open: no Wayland object exists until `mantle.lock:lock()`, and then the
-- compositor creates one surface per output.
return lock {
    id = "lock_screen",
    child = content,
}
