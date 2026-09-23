-- Pairing prompt for the Supervisor's `org.bluez.Agent1`. A device in range can raise it, so it is a
-- top card with no scrim, no pointer grab and no keyboard. A code display's button only dismisses.
local theme = require("config.theme")
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

-- A signal of `read(request)`, empty while nothing is asked.
local function text(read)
    return mantle.bluetooth:map(function(bluetooth)
        local asked = request(bluetooth)
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

return panel {
    id = "bluetooth_pairing",
    namespace = "mantle-bluetooth-pairing",
    layer = "Overlay",
    -- Top edge only. The protocol centres an axis with neither edge anchored, and with no `width` or
    -- `height` the surface is the card.
    anchor = { top = true },
    margin = { top = theme.s(96, 64) },
    exclusive = false,
    visible = when(function()
        return true
    end),
    keyboard_interactivity = "None",
    child = panel_card({
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
                action_button("Reject", answer(false), "bluetooth-pairing-reject", {
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
                action_button("Done", answer(false), "bluetooth-pairing-done", {
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
    }),
}
