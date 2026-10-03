-- Polkitd's authorization prompt; reading `mantle.polkit` registers this shell as the session
-- agent. `secure_submit` keeps the password in a native buffer no callback can read, and
-- `submit = true` makes Authenticate equal Enter. Its own Overlay surface, since it must take the
-- keyboard over anything, with `modal.lua`'s motion so it opens like every other dialog.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local panel_card = require("components.panel_card")
local action_button = require("components.action_button")
local input = require("components.input")
local modal = require("components.modal")
local scrim = require("components.scrim")

local active = util.shown_when(mantle.polkit, function(polkit)
    return polkit.active
end)

util.auto_english_layout(mantle.polkit)

local function cancel()
    mantle.polkit:cancel()
end

-- Mapped through the card's exit fade.
local shown = util.linger(active, theme.animation_ms)

return panel {
    id = "polkit_dialog",
    -- One instance, on the output the compositor picks at each show.
    output = "active",
    namespace = "mantle-polkit",
    layer = "overlay",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive_zone = false,
    width = "fill",
    height = "fill",
    visible = shown,
    -- Exclusive while open: the sole `secure_submit` field is armed on keyboard focus, so no click
    -- is needed (see `modules/global/lock.lua`).
    keyboard_interactivity = util.choose(shown, "exclusive", "none"),
    child = rect {
        width = "fill",
        height = "fill",
        children = {
            scrim(active),
            modal({ kind = "polkit", showing = active, card = panel_card({
                row {
                    width = "fill",
                    spacing = theme.spacing.lg,
                    children = {
                        icon {
                            name = util.label(mantle.polkit, function(polkit)
                                return polkit.icon_name ~= "" and polkit.icon_name or "dialog-password"
                            end),
                            size = theme.icon.xl,
                            align_v = "center",
                        },
                        cell(util.bold(util.label(mantle.polkit, function(polkit)
                            return polkit.message
                        end)), theme.FG, theme.font.md, { width = "fill", wrap = "word", align_v = "center" }),
                    },
                },
                input {
                    field = textfield {
                        placeholder = "Password",
                        mask_character = "•",
                        secure_submit = { capability = "polkit", action = "authenticate" },
                        on_cancel = cancel,
                    },
                    error = mantle.polkit:map(function(polkit)
                        return polkit and polkit.error or ""
                    end),
                },
                cell("Checking…", theme.DIM, theme.font.sm, {
                    width = "fill",
                    visible = util.shown_when(mantle.polkit, function(polkit)
                        return polkit.authenticating
                    end),
                }),
                row {
                    width = "fill",
                    align_h = "end",
                    spacing = theme.spacing.sm,
                    children = {
                        action_button("Cancel", cancel, "polkit-cancel", { tone = "quiet" }),
                        action_button("Authenticate", nil, "polkit-authenticate", { tone = "solid", submit = true }),
                    },
                },
            }, {
                width = theme.dialog_width,
                tone = "dialog",
            }) }).node,
        },
    },
}
