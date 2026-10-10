-- The lock and polkit cards' body: a round badge beside a title and its dim line, then a secure
-- field in a pill with a spinning submit, a border that turns accent while checking and red on failure, a shake per
-- failure, then the layout, Caps Lock and one feedback line reserved so nothing moves the input,
-- or with a `footer`, one line of Caps Lock, feedback and that footer.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local icon_button = require("components.icon_button")
local info_badge = require("components.info_badge")

local FIELD_HEIGHT = theme.control.xl
local BADGE_SIZE = FIELD_HEIGHT
-- Centre both controls on the pill's rounded ends.
local ICON_INSET = (FIELD_HEIGHT - theme.icon.md) / 2
local BUTTON_INSET = (FIELD_HEIGHT - theme.control.lg) / 2
-- A wrong password shakes the pill left and right, damping out.
local SHAKE = {
    duration = 60,
    easing = "in_out_quad",
    keyframes = { { x = 0 }, { x = -10 }, { x = 10 }, { x = -6 }, { x = 6 }, { x = -2 }, { x = 0 } },
}
local ERROR_TEXT = {
    ["authentication failed"] = "Incorrect password. Try again.",
    ["too many attempts"] = "Too many attempts. Try again later.",
}

---@class PasswordPromptOpts
---@field capability "lock"|"polkit" Takes the secure submit; its state drives busy and failure.
---@field slot string Unique per output.
---@field idle? string Feedback while waiting for input.
---@field status? fun(state: table?): string? A message that outranks the default feedback.
---@field on_cancel? fun() Escape in the field.
---@field font_size? number
---@field badge table Centred in the round badge.
---@field title string|Bound Bold.
---@field title_size number
---@field subtitle string|Bound Dim, below the title.
---@field footer? table Ends one compact line of Caps Lock and feedback, in place of the layout and hint lines.

---@param opts PasswordPromptOpts
return function(opts)
    local source = mantle[opts.capability]
    local busy = util.shown_when(source, function(state)
        return state.authenticating or state.unlocking
    end)
    local failed = util.shown_when(source, function(state)
        return state.active and not state.authenticating and not state.unlocking and (state.error or "") ~= ""
    end)
    -- Each failure ends an attempt, so the falling edge of `authenticating` replays the shake.
    local shaking = computed({ pulse(source:map(function(state)
        return state ~= nil and state.authenticating
    end), SHAKE.duration * #SHAKE.keyframes), failed }, function(fresh, error_shown)
        return fresh and error_shown
    end)
    local feedback = source:map(function(state)
        local status = opts.status and opts.status(state)
        if status then
            return status
        end
        if state and state.authenticating then
            return "Checking…"
        end
        local error = state and state.error or ""
        return ERROR_TEXT[error] or (error ~= "" and error) or opts.idle or ""
    end)
    local font_size = opts.font_size or theme.font.lg

    local caps = info_badge("Caps lock", theme.YELLOW, {
        visible = util.shown_when(mantle.keyboard, function(keyboard)
            return keyboard.caps_lock == true
        end),
    })
    local message = cell(feedback, util.choose(failed, theme.RED, theme.DIM), font_size, {
        width = "fill", align = "start", align_v = opts.footer and "center" or "start", wrap = "word", max_lines = 2,
    })

    local unlock = icon_button(icons.chevron_right, nil, {
        slot = opts.slot,
        size = theme.control.lg,
        icon_size = theme.icon.md,
        border = false,
        background = theme.GLASS_CONTROL,
        background_hover = theme.ACCENT_LIGHT,
        foreground = theme.FG,
        spinning = busy,
        cursor = util.choose(busy, "default", "pointer"),
    })
    unlock.submit = util.choose(busy, false, true)

    return column {
        width = "fill",
        spacing = theme.spacing.lg,
        children = {
            row {
                width = "fill",
                spacing = theme.spacing.md,
                children = {
                    rect {
                        width = BADGE_SIZE,
                        height = BADGE_SIZE,
                        radius = BADGE_SIZE / 2,
                        background = theme.GLASS_CONTROL,
                        children = { opts.badge },
                    },
                    column {
                        width = "fill",
                        align_v = "center",
                        spacing = theme.spacing.xs,
                        children = {
                            cell(util.bold(opts.title), theme.FG, opts.title_size, { width = "fill", wrap = "word" }),
                            cell(opts.subtitle, theme.DIM, theme.font.sm, { width = "fill", wrap = "word" }),
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
                radius = FIELD_HEIGHT / 2,
                border_width = theme.border_width_medium,
                border_color = computed({ busy, failed }, function(checking, error_shown)
                    return checking and theme.ACCENT or error_shown and theme.RED or theme.GLASS_BORDER
                end),
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
                    -- Passwords stay in the native buffer. Never attach `on_change` or `on_submit`.
                    textfield {
                        width = "fill",
                        height = FIELD_HEIGHT,
                        placeholder = "Password",
                        mask_character = "•",
                        secure_submit = { capability = opts.capability, action = "authenticate" },
                        on_cancel = opts.on_cancel,
                        font_size = font_size,
                        foreground = theme.FG,
                        align_v = "center",
                    },
                    unlock,
                },
            },
            opts.footer and row {
                width = "fill",
                padding = { left = ICON_INSET },
                spacing = theme.spacing.sm,
                align_v = "center",
                children = { caps, message, opts.footer },
            } or column {
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
                            caps,
                        },
                    },
                    -- Both lines stay reserved, so an error or Caps Lock never moves the input.
                    rect {
                        width = "fill",
                        height = theme.control.lg,
                        padding = { left = theme.icon.md + theme.spacing.sm },
                        children = { message },
                    },
                },
            },
        },
    }
end
