local theme = require("config.theme")
local cell = require("components.cell")
local util = require("lib.util")

---@class InputOpts
---@field field Node The `textfield` node.
---@field error? string|Bound Error text. Empty means no error.
---@field width? Length|Bound
---@field height? Length|Bound Field height. Default `theme.control.md`.
---@field visible? boolean|Bound
---@field background? Color|Bound
---@field border_color? Color|Bound Normal border. Default `theme.ACCENT`.
---@field padding? number|Edges|Bound

---@param opts InputOpts
return function(opts)
    local error = opts.error
    local error_shown
    local error_text
    if type(error) == "userdata" then
        ---@cast error Signal
        error_shown = util.shown_when(error, function(message)
            return message ~= nil and message ~= ""
        end)
        error_text = error:map(function(message)
            return message and message ~= "" and ("⚠ " .. message) or ""
        end)
    else
        error_shown = error ~= nil and error ~= ""
        error_text = error and ("⚠ " .. error) or ""
    end

    local border_color = opts.border_color or theme.ACCENT
    local border_width = theme.border_width
    if type(error_shown) == "userdata" then
        border_color = computed({ error_shown }, function(has_error)
            return has_error and theme.RED or (opts.border_color or theme.ACCENT)
        end)
        border_width = error_shown:map(function(has_error)
            return has_error and theme.border_width_medium or theme.border_width
        end)
    elseif error_shown then
        border_color = theme.RED
        border_width = theme.border_width_medium
    end

    local children = {
        rect {
            width = "Fill",
            height = opts.height or theme.control.md,
            background = opts.background or theme.GLASS_INPUT,
            radius = theme.radius.md,
            border_width = border_width,
            border_color = border_color,
            padding = opts.padding or {
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

    if error ~= nil then
        local lingering = type(error_shown) == "userdata" and util.linger(error_shown, theme.animation_ms) or error_shown
        local error_opacity = type(error_shown) == "userdata"
            and error_shown:map(function(has_error)
                return has_error and 1 or 0
            end)
            or (error_shown and 1 or 0)
        children[#children + 1] = row {
            width = "Fill",
            spacing = theme.spacing.xs,
            visible = lingering,
            opacity = error_opacity,
            animate = { opacity = theme.animation_ms },
            children = { cell(error_text, theme.RED, theme.font.sm, { width = "Fill", wrap = "Word" }) },
        }
    end

    return column {
        width = opts.width or "Fill",
        visible = opts.visible,
        spacing = theme.spacing.xs,
        children = children,
    }
end
