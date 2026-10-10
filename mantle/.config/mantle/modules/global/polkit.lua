-- Polkitd's authorization prompt; reading `mantle.polkit` registers this shell as the session
-- agent. `secure_submit` keeps the password in a native buffer no callback can read, and
-- the pill's chevron submits like Enter. Its own Overlay surface, since it must take the
-- keyboard over anything, with `modal.lua`'s motion so it opens like every other dialog.
local theme = require("config.theme")
local util = require("lib.util")
local panel_card = require("components.panel_card")
local action_button = require("components.action_button")
local password_prompt = require("components.password_prompt")
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
                password_prompt({
                    capability = "polkit",
                    slot = "polkit-authenticate",
                    font_size = theme.font.md,
                    on_cancel = cancel,
                    badge = icon {
                        name = util.label(mantle.polkit, function(polkit)
                            return polkit.icon_name ~= "" and polkit.icon_name or "dialog-password"
                        end),
                        size = theme.icon.lg,
                        align_h = "center",
                        align_v = "center",
                    },
                    title = util.label(mantle.polkit, function(polkit)
                        return polkit.message
                    end),
                    title_size = theme.font.md,
                    -- What is being granted, so a vague message can still be judged.
                    subtitle = util.label(mantle.polkit, function(polkit)
                        return polkit.action_id
                    end),
                    footer = action_button("Cancel", cancel, "polkit-cancel", { tone = "quiet" }),
                }),
            }, {
                width = theme.dialog_width,
                tone = "dialog",
                padding = theme.spacing.xl,
                radius = theme.radius.xl,
            }) }).node,
        },
    },
}
