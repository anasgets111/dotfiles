-- Polkitd's authorization prompt; reading `mantle.polkit` registers this shell as the session
-- agent. `secure_submit` keeps the password in a native buffer no callback can read, and
-- `submit = true` makes Authenticate equal Enter.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local panel_card = require("components.panel_card")
local action_button = require("components.action_button")
local input = require("components.input")

local active = util.shown_when(mantle.polkit, function(polkit)
    return polkit.active
end)

util.auto_english_layout(mantle.polkit)

return panel {
    id = "polkit_dialog",
    namespace = "mantle-polkit",
    layer = "Overlay",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive = false,
    width = "Fill",
    height = "Fill",
    visible = active,
    -- Exclusive while open: the sole `secure_submit` field is armed on keyboard focus, so no click
    -- is needed (see `modules/global/lock.lua`).
    keyboard_interactivity = active:map(function(open)
        return open and "Exclusive" or "None"
    end),
    child = rect {
        width = "Fill",
        height = "Fill",
        background = theme.SCRIM,
        children = {
            panel_card({
                row {
                    width = "Fill",
                    spacing = theme.spacing.lg,
                    children = {
                        icon {
                            name = util.label(mantle.polkit, function(polkit)
                                return polkit.icon_name ~= "" and polkit.icon_name or "dialog-password"
                            end),
                            size = theme.icon.xl,
                            align_v = "Center",
                        },
                        column {
                            width = "Fill",
                            spacing = theme.spacing.xs,
                            children = {
                                cell(util.bold(util.label(mantle.polkit, function(polkit)
                                    return polkit.message
                                end)), theme.FG, theme.font.md, { width = "Fill", wrap = "Word" }),
                                cell(util.label(mantle.polkit, function(polkit)
                                    return polkit.action_id
                                end), theme.DIM, theme.font.xs, { width = "Fill" }),
                            },
                        },
                    },
                },
                -- `PolkitState` carries no prompt text, so the label is fixed.
                cell("Password:", theme.FG, theme.font.sm),
                input {
                    field = textfield {
                        width = "Fill",
                        height = "Fill",
                        placeholder = "Password",
                        mask_character = "*",
                        secure_submit = { capability = "polkit", action = "authenticate" },
                        font_size = theme.font.sm,
                        foreground = theme.FG,
                    },
                    error = mantle.polkit:map(function(polkit)
                        return polkit and polkit.error or ""
                    end),
                },
                cell("Checking...", theme.DIM, theme.font.sm, {
                    width = "Fill",
                    visible = util.shown_when(mantle.polkit, function(polkit)
                        return polkit.authenticating
                    end),
                }),
                row {
                    width = "Fill",
                    align_h = "End",
                    spacing = theme.spacing.sm,
                    children = {
                        action_button("Cancel", function()
                            mantle.polkit:invoke("cancel")
                        end, "polkit-cancel", { tone = "quiet" }),
                        action_button("Authenticate", nil, "polkit-authenticate", { tone = "solid", submit = true }),
                    },
                },
            }, {
                width = theme.dialog_width,
                align_h = "Center",
                align_v = "Center",
                spacing = theme.spacing.md,
                padding = theme.spacing.lg,
                tone = "dialog",
            }),
        },
    },
}
