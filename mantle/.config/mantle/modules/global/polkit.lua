-- Polkitd's authorization prompt. Reading `mantle.polkit` registers this shell as the
-- session agent.
--
-- Escape clears the masked field and stays; `mask_character` is one byte. `submit = true` makes Authenticate equal Enter; the
-- password remains in a native buffer no callback can read.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local panel_card = require("components.panel_card")
local action_button = require("components.action_button")
local input = require("components.input")

local function read(fn)
    return util.label(mantle.polkit, fn)
end

local active = util.shown_when(mantle.polkit, function(p)
    return p.active
end)

util.auto_english_layout(mantle.polkit)

local pad = theme.spacing.lg

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
                            name = read(function(p)
                                return p.icon_name ~= "" and p.icon_name or "dialog-password"
                            end),
                            size = theme.icon.xl,
                            align_v = "Center",
                        },
                        column {
                            width = "Fill",
                            spacing = theme.spacing.xs,
                            children = {
                                cell(read(function(p)
                                    return { { text = p.message, bold = true } }
                                end), theme.FG, theme.font.md, { width = "Fill", wrap = "Word" }),
                                cell(read(function(p)
                                    return p.action_id
                                end), theme.DIM, theme.font.xs, { width = "Fill" }),
                            },
                        },
                    },
                },
                -- polkitd's own prompt text can replace this line and hide it when empty.
                -- `PolkitState` carries no such field, so this stays the fixed label the prompt
                -- always is in practice.
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
                    error = mantle.polkit:map(function(p)
                        return p and p.error or ""
                    end),
                },
                cell("Checking...", theme.DIM, theme.font.sm, {
                    width = "Fill",
                    visible = util.shown_when(mantle.polkit, function(p)
                        return p.authenticating
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
                padding = { top = pad, right = pad, bottom = pad, left = pad },
                radius = theme.radius.lg,
                background = theme.GLASS,
                blur = true,
                border_width = theme.border_width,
                border_color = theme.BORDER,
            }),
        },
    },
}
