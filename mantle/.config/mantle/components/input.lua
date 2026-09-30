local theme = require("config.theme")
local icons = require("config.icons")
local callout = require("components.callout")
local util = require("lib.util")

---@class InputOpts
---@field field Node The `textfield` node.
---@field error? Signal Error text. Empty means no error.
---@field visible? boolean|Bound

---@param opts InputOpts
return function(opts)
    local field = opts.field
    field.width = field.width or "Fill"
    field.height = field.height or "Fill"
    field.font_size = field.font_size or theme.font.sm
    field.foreground = field.foreground or theme.FG
    local error = opts.error
    local error_shown = error and util.shown_when(error, function(message)
        return message ~= ""
    end)
    local children = {
        rect {
            width = "Fill",
            height = theme.control.md,
            background = theme.GLASS_INPUT,
            radius = theme.radius.md,
            border_width = util.choose(error_shown, theme.border_width_medium, theme.border_width),
            border_color = util.choose(error_shown, theme.RED, theme.ACCENT),
            padding = {
                top = theme.spacing.xs,
                right = theme.spacing.sm,
                bottom = theme.spacing.xs,
                left = theme.spacing.sm,
            },
            animate = {
                border_color = theme.animation_ms,
                border_width = theme.animation_ms,
            },
            children = { opts.field },
        },
    }

    if error and error_shown then
        children[2] = row {
            width = "Fill",
            visible = util.linger(error_shown, theme.animation_ms),
            opacity = util.choose(error_shown, 1, 0),
            animate = { opacity = theme.animation_ms },
            children = { callout(icons.warning, error:map(function(message)
                return message or ""
            end)) },
        }
    end

    return column {
        width = "Fill",
        visible = opts.visible,
        spacing = theme.spacing.xs,
        children = children,
    }
end
