-- Pairing prompt for the Supervisor's `org.bluez.Agent1`. A device in range can raise it, so it is a
-- top card with no scrim, no pointer grab and no keyboard. A code display's button only dismisses.
-- It moves like `components/modal.lua`'s cards: fade and drop in, rise out.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local panel_card = require("components.panel_card")
local action_button = require("components.action_button")

local function request(bluetooth)
    return bluetooth and bluetooth.pairing_request
end

-- A signal of `predicate(request)`, false while nothing is asked.
local function when(predicate)
    return mantle.bluetooth:map(function(bluetooth)
        local asked = request(bluetooth)
        return asked ~= nil and predicate(asked)
    end)
end

-- The last request, so the card keeps its words while it fades out after the answer.
local last_asked
local held = mantle.bluetooth:map(function(bluetooth)
    last_asked = request(bluetooth) or last_asked
    return last_asked
end)

-- A signal of `read(request)`, empty before anything was asked.
local function text(read)
    return held:map(function(asked)
        return asked and read(asked) or ""
    end)
end

-- Kind to `{ title format, detail }`.
local PROMPTS = {
    confirm = { "Pair with %s?", "Pair only if the device shows the same code" },
    authorize = { "%s wants to pair", "Accept only a device you are pairing right now" },
    service = { "%s wants to connect", "The device is paired but not trusted" },
    display = { "Type this code on %s", "Then press Enter on the device" },
}

-- Answers by MAC; the Supervisor ignores a yes in a request's first moments (`ACCEPT_GRACE`).
local function answer(accept)
    return function()
        local asked = request(mantle.bluetooth:get())
        if asked ~= nil then
            mantle.bluetooth:invoke("answer_pairing", asked.mac, accept)
        end
    end
end

local asks = when(function(asked)
    return asked.kind ~= "display"
end)

local showing = when(function()
    return true
end)
local motion = showing:map(function(open)
    local easing = open and "OutCubic" or "InCubic"
    return {
        opacity = { duration = theme.animation_ms, easing = easing, from = 0 },
        translate = { duration = theme.animation_ms, easing = easing, from = { y = -theme.spacing.md } },
    }
end)

return panel {
    id = "bluetooth_pairing",
    namespace = "mantle-bluetooth-pairing",
    layer = "Overlay",
    -- Top edge only. The protocol centres an axis with neither edge anchored, and with no `width` or
    -- `height` the surface is the card.
    anchor = { top = true },
    margin = { top = theme.s(96, 64) },
    exclusive = false,
    visible = util.linger(showing, theme.animation_ms),
    keyboard_interactivity = "None",
    child = rect {
        opacity = showing:map(function(open)
            return open and 1 or 0
        end),
        translate = showing:map(function(open)
            return { y = open and 0 or -theme.spacing.md }
        end),
        animate = motion,
        children = { panel_card({
            cell(text(function(asked)
                -- The name is the device's own choice, so the MAC stays beside it.
                local name = asked.name ~= "" and string.format("%s (%s)", asked.name, asked.mac) or asked.mac
                return { { text = string.format((PROMPTS[asked.kind] or {})[1] or "%s", name), bold = true } }
            end), theme.FG, theme.font.md, { width = "Fill", wrap = "Word" }),
            cell(text(function(asked)
                return asked.code or ""
            end), theme.ACCENT, theme.font.xxl, {
                width = "Fill",
                align = "Center",
                visible = when(function(asked)
                    return asked.code ~= nil
                end),
            }),
            cell(text(function(asked)
                return (PROMPTS[asked.kind] or {})[2] or ""
            end), theme.DIM, theme.font.sm, { width = "Fill", wrap = "Word" }),
            row {
                width = "Fill",
                align_h = "End",
                spacing = theme.spacing.sm,
                children = {
                    action_button("Cancel", answer(false), "bluetooth-pairing-reject", {
                        tone = "quiet",
                        visible = asks,
                    }),
                    action_button(
                        text(function(asked)
                            return asked.kind == "service" and "Allow" or "Pair"
                        end),
                        answer(true),
                        "bluetooth-pairing-accept",
                        { tone = "solid", visible = asks }
                    ),
                    action_button("Close", answer(false), "bluetooth-pairing-done", {
                        tone = "solid",
                        visible = when(function(asked)
                            return asked.kind == "display"
                        end),
                    }),
                },
            },
        }, {
            width = theme.dialog_width,
            spacing = theme.spacing.md,
            padding = theme.spacing.lg,
            tone = "dialog",
        }) },
    },
}
