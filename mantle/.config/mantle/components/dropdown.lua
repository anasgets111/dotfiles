-- A select: a trigger showing the current value, and an `xdg_popup` list under it. The popup is a
-- surface, so the caller adds `popup` to the surface set once and builds the trigger with
-- `trigger()`, which a `list` `itemfn` may call on every rebuild.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local glyph = require("components.glyph")
local panel_card = require("components.panel_card")
local util = require("lib.util")

---@class DropdownOpts
---@field id string Unique; names the popup, its open state and its hover slots.
---@field parent string The surface the trigger sits on.
---@field options Signal<any[]> The values, in list order.
---@field value Signal<any> The selected value, marked in the list.
---@field format fun(value: any): string
---@field on_select fun(value: any)

---@class Dropdown
---@field trigger fun(): table
---@field popup table

---@param opts DropdownOpts
---@return Dropdown
return function(opts)
    local open = state(opts.id .. "-open", false)
    -- The keyboard's highlighted value, which Enter picks.
    local cursor = state(opts.id .. "-cursor", false)
    local slot = opts.id .. "-trigger"
    local hovered = hover(slot)

    -- The value `delta` rows from `from`, clamped to the ends: a wheel or arrow that wraps overshoots.
    local function step(from, delta)
        local options = opts.options:get()
        local index = 0
        for position, value in ipairs(options) do
            if value == from then
                index = position
            end
        end
        return options[math.max(1, math.min(#options, index + delta))]
    end

    local function option(value)
        local option_hovered = hover(opts.id .. "-" .. tostring(value))
        local current = opts.value:map(function(selected)
            return selected == value
        end)
        local ink = current:map(function(on)
            return on and theme.ACCENT or theme.FG
        end)
        return button {
            width = "Fill",
            height = theme.control.sm,
            radius = theme.radius.sm,
            hover = option_hovered,
            background = computed({ option_hovered, cursor }, function(hot, highlighted)
                return (hot or highlighted == value) and theme.GLASS_HOVER or theme.CLEAR
            end),
            on_click = function()
                open:set(false)
                opts.on_select(value)
            end,
            children = { row {
                width = "Fill",
                height = "Fill",
                align_v = "Center",
                spacing = theme.spacing.xs,
                padding = { left = theme.spacing.sm, right = theme.spacing.xs },
                children = {
                    cell(util.bold_when(current, opts.format(value)), ink, theme.font.xs,
                        { width = "Fill", align_v = "Center" }),
                    glyph(icons.check, ink, theme.icon.xs, { align_v = "Center", visible = current }),
                },
            } },
        }
    end

    local wheel = 0
    local function trigger()
        return button {
            width = "Fill",
            height = theme.control.sm,
            align_v = "Center",
            radius = theme.radius.sm,
            hover = hovered,
            background = hovered:map(function(hot)
                return hot and theme.GLASS_HOVER or theme.GLASS_CONTENT
            end),
            border_width = theme.border_width,
            border_color = open:map(function(on)
                return on and theme.ACCENT or theme.GLASS_BORDER
            end),
            animate = { border_color = theme.animation_ms },
            on_click = function(_, mouse_button)
                if mouse_button == "left" then
                    cursor:set(opts.value:get())
                    open:set(not open:get())
                end
            end,
            -- Notches accumulate, so a touchpad's fractions step once per notch.
            on_wheel = function(_, steps)
                wheel = wheel + steps
                while math.abs(wheel) >= 1 do
                    local delta = wheel > 0 and 1 or -1
                    wheel = wheel - delta
                    opts.on_select(step(opts.value:get(), delta))
                end
            end,
            children = { row {
                width = "Fill",
                height = "Fill",
                align_v = "Center",
                spacing = theme.spacing.xs,
                padding = { left = theme.spacing.sm, right = theme.spacing.xs },
                children = {
                    cell(opts.value:map(opts.format), theme.FG, theme.font.xs,
                        { width = "Fill", align_v = "Center" }),
                    glyph(open:map(function(on)
                        return on and icons.chevron_up or icons.chevron_down
                    end), theme.DIM, theme.icon.xs, { align_v = "Center" }),
                },
            } },
        }
    end

    -- Closing the parent surface dismisses the popup, which resets `open` for the next showing.
    local popup_node = popup {
        id = opts.id,
        parent = opts.parent,
        anchor_rect = hover_rect(slot),
        visible = open,
        anchor = "Bottom",
        gravity = "Bottom",
        offset = { y = theme.spacing.xs },
        on_dismiss = function()
            open:set(false)
        end,
        child = panel_card({
            list {
                width = "Fill",
                source = opts.options,
                key = tostring,
                itemfn = option,
            },
            -- Grabbed popups take the keyboard, so arrows, Enter and Escape land here.
            textfield {
                width = 0,
                height = 0,
                autofocus = true,
                on_change = function() end,
                on_navigate = function(key)
                    local delta = ({ up = -1, backtab = -1, down = 1, tab = 1, page_up = -math.huge, page_down = math.huge })
                        [key]
                    cursor:set(step(cursor:get(), delta))
                end,
                on_submit = function()
                    open:set(false)
                    opts.on_select(cursor:get())
                end,
                on_cancel = function()
                    open:set(false)
                end,
            },
        }, {
            width = hover_rect(slot):map(function(rect)
                return rect.width
            end),
            spacing = 0,
            padding = theme.spacing.xs,
            radius = theme.radius.md,
            background = theme.GLASS_SURFACE,
            blur = true,
            border_width = theme.border_width,
            border_color = theme.GLASS_BORDER,
        }),
    }

    return { trigger = trigger, popup = popup_node }
end
