-- Pairing prompt for the Supervisor's `org.bluez.Agent1`. A device in range can raise it, so it is a
-- top card with no scrim and no pointer grab; it takes the keyboard only for a PIN or passkey entry.
-- A code display's button only dismisses.
-- It moves like `components/modal.lua`'s cards: fade and drop in, rise out.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local input = require("components.input")
local panel_card = require("components.panel_card")
local action_button = require("components.action_button")
local card_motion = require("components.card_motion")

local request = mantle.bluetooth:map(function(bluetooth)
    return bluetooth and bluetooth.pairing_request
end)

-- A signal of `predicate(request)`, false while nothing is asked.
local function when(predicate)
    return request:map(function(asked)
        return asked ~= nil and predicate(asked)
    end)
end

-- The last request, so the card keeps its words while it fades out after the answer.
local held = util.hold(request, false)

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
    pin_entry = { "PIN for %s", "Letters or digits, up to 16" },
    passkey_entry = { "Passkey for %s", "Up to 6 digits" },
}

local function is_entry(asked)
    return asked.kind == "pin_entry" or asked.kind == "passkey_entry"
end

-- Answers by MAC; the Supervisor ignores a yes in a request's first moments (`ACCEPT_GRACE`).
local function answer(accept)
    return function()
        local asked = request:get()
        if asked ~= nil then
            mantle.bluetooth:answer_pairing(asked.mac, accept)
        end
    end
end

local entry = when(is_entry)

local asks = when(function(asked)
    return asked.kind ~= "display" and not is_entry(asked)
end)

local showing = when(function()
    return true
end)

return panel {
    id = "bluetooth_pairing",
    -- One instance, on the output the compositor picks at each show.
    output = "active",
    namespace = "mantle-bluetooth-pairing",
    layer = "overlay",
    -- Top edge only. The protocol centres an axis with neither edge anchored, and with no `width` or
    -- `height` the surface is the card.
    anchor = { top = true },
    margin = { top = theme.dialog_top_margin },
    exclusive_zone = false,
    visible = util.linger(showing, theme.animation_ms),
    -- Exclusive while asking for a secret: the sole `secure_submit` field arms on keyboard focus.
    keyboard_interactivity = util.choose(entry, "exclusive", "none"),
    child = rect(card_motion({
        children = { panel_card({
            cell(text(function(asked)
                -- The name is the device's own choice, so the MAC stays beside it.
                local name = asked.name ~= "" and string.format("%s (%s)", asked.name, asked.mac) or asked.mac
                return { { text = string.format((PROMPTS[asked.kind] or {})[1] or "%s", name), bold = true } }
            end), theme.FG, theme.font.md, { width = "fill", wrap = "word" }),
            cell(text(function(asked)
                return asked.code or ""
            end), theme.ACCENT, theme.font.xxl, {
                width = "fill",
                align = "center",
                visible = when(function(asked)
                    return asked.code ~= nil
                end),
            }),
            cell(text(function(asked)
                return (PROMPTS[asked.kind] or {})[2] or ""
            end), theme.DIM, theme.font.sm, { width = "fill", wrap = "word" }),
            input {
                field = textfield {
                    height = theme.control.md - 2 * theme.spacing.xs,
                    placeholder = text(function(asked)
                        return asked.kind == "passkey_entry" and "Passkey" or "PIN"
                    end),
                    mask_character = "•",
                    accessible_name = "Bluetooth PIN or passkey",
                    secure_submit = request:map(function(asked)
                        if asked ~= nil and is_entry(asked) then
                            return { capability = "bluetooth", action = "pair", name = asked.id .. "/" .. asked.mac }
                        end
                    end),
                    on_cancel = answer(false),
                },
                visible = entry,
            },
            row {
                width = "fill",
                align_h = "end",
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
                    action_button("Cancel", answer(false), "bluetooth-pairing-decline", {
                        tone = "quiet",
                        visible = entry,
                    }),
                    action_button("Pair", nil, "bluetooth-pairing-submit", {
                        tone = "solid",
                        submit = true,
                        visible = entry,
                    }),
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
            tone = "dialog",
        }) },
    }, showing, { scale = false })),
}
