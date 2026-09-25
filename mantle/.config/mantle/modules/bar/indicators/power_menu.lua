-- The bar pill runs log out, restart and power off after a ten-second countdown. `process.detach`
-- shells out, so a Renderer crash mid-flight cannot reap a shutdown. The countdown is a
-- `mantle.system.monotonic` deadline, not a timer, so a clock step cannot fire it early.
local theme = require("config.theme")
local icons = require("config.icons")
local tooltip = require("components.tooltip")
local expanding_pill = require("components.expanding_pill")
local compositor = require("lib.compositor")

local COUNTDOWN = 10

-- Pending action (`""` for none) and its `mantle.system.monotonic` deadline.
local pending = state("power_pending", "")
local deadline = state("power_deadline", 0)

local seconds_left = computed({ mantle.system, deadline }, function(system, at)
    return math.max(0, at - ((system and system.monotonic) or 0))
end)

-- In order. `logout` is the compositor's own exit, so it goes through `lib.compositor`; reboot
-- and poweroff are logind's and need no branch.
local ACTIONS = {
    {
        key = "logout",
        label = "Log out",
        icon = icons.logout,
        run = function()
            compositor.detach("logout")
        end
    },
    {
        key = "reboot",
        label = "Restart",
        icon = icons.power,
        run = function()
            process.detach("systemctl", { "reboot" })
        end
    },
    {
        key = "poweroff",
        label = "Power off",
        icon = icons.shutdown,
        run = function()
            process.detach("systemctl", { "poweroff" })
        end
    },
}

-- Also keyed, so `pending` looks its action up without a search; `ipairs` still sees the three.
for _, action in ipairs(ACTIONS) do
    ACTIONS[action.key] = action
end

local function commit_pending()
    local action = ACTIONS[pending:get()]
    pending:set("")
    if action then
        action.run()
    end
end

mantle.system:on_change(function(system)
    if pending:get() ~= "" and system.monotonic >= deadline:get() then
        commit_pending()
    end
end)

-- The power-off circle expands on hover and stays open through a countdown
-- (`components/expanding_pill.lua`). During one the chosen action pulses, the next slot shows
-- seconds over a growing fill, and the third cancels.
local SLOT_COUNT = #ACTIONS
local pill = expanding_pill.new({
    slot = "power-pill",
    count = SLOT_COUNT,
    hold_open = pending:map(function(key)
        return key ~= ""
    end),
})

-- The countdown circle is the last slot, unless that slot is the chosen action.
local function countdown_index(key)
    return key == ACTIONS[SLOT_COUNT].key and SLOT_COUNT - 1 or SLOT_COUNT
end

-- What slot `index` is while `chosen` counts down: its own action, the seconds circle, or the
-- cancel cross.
local function role_of(index, chosen)
    if chosen == "" or chosen == ACTIONS[index].key then
        return "action"
    elseif countdown_index(chosen) == index then
        return "countdown"
    end
    return "cancel"
end

local function slot(index)
    local action = ACTIONS[index]
    local role = pending:map(function(key)
        return role_of(index, key)
    end)
    local is_chosen = pending:map(function(key)
        return key == action.key
    end)
    local slot_hovered = hover("power-" .. action.key)
    return pill.cell(button {
        align_h = "Center",
        hover = slot_hovered,
        radius = theme.item_radius,
        -- Plain fill bar cut by the circle's arc, under a clip.
        clip = "Rounded",
        background = computed({ slot_hovered, role }, function(is_hovered, what)
            return (is_hovered and what ~= "countdown") and theme.GLASS_CONTROL_HOVER or theme.GLASS_CONTROL
        end),
        border_width = theme.border_width,
        border_color = computed({ is_chosen, slot_hovered }, function(chosen, is_hovered)
            return chosen and theme.ACCENT or is_hovered and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER
        end),
        -- The chosen action breathes; without the `opacity` entry the loop stops at `1`.
        animate = is_chosen:map(function(chosen)
            local eases = { background = theme.animation_ms, border_color = theme.animation_ms }
            if chosen then
                eases.opacity = {
                    duration = theme.animation_slow_ms,
                    easing = "InOutQuad",
                    loops = "Infinite",
                    keyframes = { 1, 0.4, 1 },
                }
            end
            return eases
        end),
        children = {
            -- Elapsed seconds grow a ground from the left under the number.
            rect {
                width = computed({ role, seconds_left }, function(what, left)
                    if what ~= "countdown" then
                        return "0%"
                    end
                    local gone = math.max(0, COUNTDOWN - left)
                    return string.format("%d%%", math.floor(gone * 100 / COUNTDOWN + 0.5))
                end),
                height = "Fill",
                background = theme.ON_HOVER,
                animate = { width = theme.animation_ms },
            },
            text {
                content = computed({ role, seconds_left }, function(what, left)
                    if what == "countdown" then
                        return tostring(left)
                    elseif what == "cancel" then
                        return icons.close
                    end
                    return action.icon
                end),
                foreground = theme.FG,
                font_size = role:map(function(what)
                    return what == "countdown" and theme.font.sm or theme.icon.lg
                end),
                -- The countdown uses the declared font for digits; resting and cancel states use
                -- the icon font. `nil` selects the declared chain.
                font = role:map(function(what)
                    return what ~= "countdown" and theme.icon_font or nil
                end),
                align_h = "Center",
                align_v = "Center",
            },
        },
        on_click = function(_, mouse_button)
            local key = pending:get()
            if mouse_button == "right" then
                pending:set("")
            elseif mouse_button == "left" then
                if key == "" then
                    local system = mantle.system:get()
                    deadline:set(((system and system.monotonic) or 0) + COUNTDOWN)
                    pending:set(action.key)
                elseif key == action.key then
                    commit_pending()
                elseif countdown_index(key) ~= index then
                    pending:set("")
                end
            end
        end,
    }, pill.expanded:map(function()
        -- The collapsed index is the last slot: power off is the one circle at rest.
        return index == SLOT_COUNT
    end))
end

local slots = {}
for index = 1, SLOT_COUNT do
    slots[index] = slot(index)
end

-- What each role's circle does under the pointer while a countdown runs.
local HINTS = {
    action = "Left click runs it now · Right click cancels",
    countdown = "Right click cancels",
    cancel = "Click to cancel",
}

-- One card per circle, each hanging from its own slot, so none chases the pointer across the pill's
-- gaps. The circles are glyphs, so the card names the action and, during a countdown, its clicks.
local power_tooltips = {}
for index, action in ipairs(ACTIONS) do
    power_tooltips[index] = tooltip({
        id = "power_tooltip_" .. action.key,
        slot = "power-" .. action.key,
        text = computed({ pending, seconds_left }, function(chosen, left)
            if role_of(index, chosen) == "cancel" then
                return "Cancel"
            end
            return chosen ~= "" and string.format("%s in %ds", ACTIONS[chosen].label, left) or action.label
        end),
        detail = pending:map(function(chosen)
            return chosen == "" and "" or HINTS[role_of(index, chosen)]
        end),
    })
end

return { pill = pill, button = pill.row(slots), tooltips = power_tooltips }
