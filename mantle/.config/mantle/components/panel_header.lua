-- Masthead: tinted glyph plate, title and state line, trailing controls. The plate and glyph take
-- accent while `opts.active`, so "network" and "bluetooth" read as switches before their labels.
-- `width = "Fill"` plus `cell`'s elision keeps a long title from pushing the controls out.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local icons = require("config.icons")
local icon_button = require("components.icon_button")

---@class PanelHeaderOpts
---@field title string
---@field subtitle? string|Bound One line of state under the title: the joined network, "2 connected · P30i · 90%", "off".
---@field icon? string|Bound A glyph on a plate; the plate and glyph take `active`'s colour.
---@field active? boolean|Bound Accent while true, dim while false. Default true. Ignored when `accent` is given.
---@field accent? Color|Bound The plate and glyph colour outright, for a subject whose state is not on/off: a live capture is red and a ready one accent, neither of them "off".
---@field trailing? Node[] Controls at the far edge, in order.
---@field on_close? fun() Adds a close button after `trailing`.
---@field title_size? integer The title's font size. Default `theme.font.lg`, a bar panel's masthead; a modal's is bigger.
---@field subtitle_color? Color|Bound The state line's colour. Default `theme.DIM`.
---@field subtitle_size? integer The state line's font size. Default `theme.font.xs`, which suits a 16px title and is unreadable under a modal's 28px one.
---@field plate? integer The icon plate's side. Default `theme.control.lg`; it tracks `title_size`.

---@param opts PanelHeaderOpts
return function(opts)
    local active = opts.active == nil or opts.active
    local function by_active(on_value, off_value)
        return util.lift(active, function(on)
            return on and on_value or off_value
        end)
    end
    local function faded(colour)
        return theme.with_opacity(colour, theme.opacity.subtle)
    end
    ---@type Color|Signal
    local accent = opts.accent or by_active(theme.ACCENT, theme.DIM)
    -- An explicit accent's plate is the same colour at reduced opacity, so callers supply one, not a pair.
    ---@type Color|Signal
    local plate = opts.accent == nil and by_active(theme.ACCENT_SUBTLE, theme.GLASS_CONTENT)
        or util.lift(accent, faded)

    local plate_size = opts.plate or theme.control.lg

    local children = {}
    if opts.icon then
        children[#children + 1] = rect {
            width = plate_size,
            height = plate_size,
            radius = theme.radius.md,
            background = plate,
            animate = { background = theme.animation_ms },
            align_v = "Center",
            children = { cell(opts.icon, accent, math.floor(plate_size * 0.55), {
                align = "Center",
                align_v = "Center",
                animate = { foreground = theme.animation_ms },
            }) },
        }
    end

    local lines = { cell(util.bold(opts.title), theme.FG, opts.title_size or theme.font.lg, { width = "Fill" }) }
    if opts.subtitle then
        lines[#lines + 1] = cell(opts.subtitle, opts.subtitle_color or theme.DIM,
            opts.subtitle_size or theme.font.xs, { width = "Fill" })
    end
    children[#children + 1] = column { width = "Fill", align_v = "Center", children = lines }

    for _, control in ipairs(opts.trailing or {}) do
        control.align_v = control.align_v or "Center"
        children[#children + 1] = control
    end
    if opts.on_close then
        children[#children + 1] = icon_button(icons.close, opts.on_close,
            { size = theme.control.sm, icon_size = theme.icon.sm })
    end

    return row {
        width = "Fill",
        spacing = theme.spacing.sm,
        align_v = "Center",
        children = children,
    }
end
