-- Clock, identity, secure password field and system status over a frosted wallpaper.
local theme           = require("config.theme")
local util            = require("lib.util")
local wallpaper       = require("lib.wallpaper")
local cell            = require("components.cell")
local glyph           = require("components.glyph")
local panel_card      = require("components.panel_card")
local password_prompt = require("components.password_prompt")
local scrim           = require("components.scrim")
local identity        = require("lib.identity")
local weather         = require("lib.weather")

local WALLPAPER_BLUR  = 24
local CARD_BLUR       = 16
local STAGGER         = 90

-- Keep the lock until the card's exit finishes, plus scheduling slack.
local LEAVE_SLACK     = 60
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

-- Outranks the prompt's own feedback while the lock is coming up or going away.
local function lock_status(lock)
    if lock == nil or not lock.active then
        return "Locking…"
    end
    return lock.unlocking and "Unlocking…" or nil
end

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
        password_prompt({
            capability = "lock",
            slot = "lock-unlock-" .. output,
            idle = "Press Enter to unlock",
            status = lock_status,
            badge = cell(util.bold(identity.initials), theme.FG, theme.font.lg, {
                width = "fill", align = "center", align_v = "center",
            }),
            title = identity.full_name,
            title_size = theme.font.xl,
            subtitle = identity.account,
        }),
    }, {
        width = theme.dialog_width,
        align_h = "center",
        padding = theme.spacing.xl,
        background = theme.with_opacity(theme.ELEVATED, 0.3),
        glass = true,
        radius = theme.radius.xl,
        effect = { backdrop = { blur = CARD_BLUR } },
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
                effect = util.lift(mantle.lock, function(lock)
                    if lock == nil or not lock.active then
                        return { backdrop = { blur = 0 } }
                    end
                    return { backdrop = { blur = lock.unlocking and WALLPAPER_BLUR / 2 or WALLPAPER_BLUR } }
                end),
                animate = { effect = { duration = theme.animation_slow_ms, easing = "out_cubic", from = {} } },
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
