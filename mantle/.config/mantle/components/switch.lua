-- Shared switch paint and clicks. Callers own the payload read and the control's contents.
local theme = require("config.theme")
local util = require("lib.util")

---@class SwitchOpts
---@field width? Length
---@field height? Length
---@field radius? number
---@field rest? Color
---@field border? boolean
---@field disabled? Signal<boolean>
---@field animate? RectAnimations

---@param on Signal<boolean>
---@param slot string
---@param activate fun()
---@param opts SwitchOpts
---@return table, fun(on_hot: Color, on_rest: Color, hot: Color, rest: Color): Signal
return function(on, slot, activate, opts)
    local hovered = hover(slot)
    local tint = util.tint(on, hovered)
    local bordered = opts.border ~= false
    return {
        width = opts.width,
        height = opts.height,
        radius = opts.radius,
        hover = hovered,
        background = tint(theme.ACCENT_LIGHT, theme.ACCENT_SUBTLE, theme.GLASS_HOVER,
            opts.rest or theme.GLASS_CONTENT),
        border_width = bordered and theme.border_width or nil,
        border_color = bordered and tint(theme.ACCENT_MEDIUM, theme.ACCENT_MEDIUM,
            theme.GLASS_BORDER_HOVER, theme.GLASS_BORDER) or nil,
        opacity = opts.disabled and util.choose(opts.disabled, theme.opacity.disabled, 1),
        animate = opts.animate or {
            background = theme.animation_ms,
            border_color = bordered and theme.animation_ms or nil,
        },
        on_click = function(_, button)
            if button == "left" and not (opts.disabled and opts.disabled:get()) then
                activate()
            end
        end,
    }, tint
end
