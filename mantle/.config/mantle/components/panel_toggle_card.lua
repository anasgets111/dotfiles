local theme = require("config.theme")
local cell = require("components.cell")
local glyph = require("components.glyph")
local spinner = require("components.spinner")
local util = require("lib.util")
local switch = require("components.switch")

---@class PanelToggleCardOpts
---@field slot string The hover region's name; one per tile.
---@field icon string|Bound
---@field label string|Bound
---@field detail? string|Bound A second line, hidden while empty.
---@field signal Signal The capability whose payload `read` inspects.
---@field read fun(payload: any): boolean
---@field spinning? Signal Replaces the icon while an action runs.
---@field on_change fun(checked: boolean)
---@field disabled? Signal The tile dims and ignores clicks, for hardware that is not there.

---@param opts PanelToggleCardOpts
return function(opts)
    local checked = opts.signal:map(function(value)
        return util.read_bool(value, opts.read)
    end)

    local node, tint = switch(checked, opts.slot, function()
        opts.on_change(not util.read_bool(opts.signal:get(), opts.read))
    end, {
        width = "fill",
        height = theme.panel_toggle_height,
        radius = theme.radius.lg,
        disabled = opts.disabled,
        animate = {
            background = theme.animation_ms,
            border_color = theme.animation_ms,
            opacity = { duration = theme.animation_ms, easing = "out_cubic" },
        },
    })
    local ink = tint(theme.ACCENT, theme.ACCENT, theme.FG, theme.DIM)

    local lines = {}
    local icon = glyph(opts.icon, ink, theme.icon.md, {
        align = "center",
        visible = opts.spinning and opts.spinning:map(function(on)
            return not on
        end),
        animate = { foreground = theme.animation_ms },
    })
    lines[1] = opts.spinning and rect {
        width = theme.icon.md,
        height = theme.icon.md,
        align_h = "center",
        align_v = "center",
        children = { icon, spinner(opts.spinning, theme.icon.md, ink) },
    } or icon
    lines[#lines + 1] = cell(opts.label, ink, theme.font.xs, {
        bold = checked,
        align = "center",
        animate = { foreground = theme.animation_ms },
    })
    if opts.detail ~= nil then
        lines[#lines + 1] = cell(opts.detail, tint(theme.TEXT_ACTIVE, theme.TEXT_ACTIVE, theme.TEXT_ACTIVE, theme.DIM),
            theme.font.xs, {
                align = "center",
                align_v = "center",
                visible = util.lift(opts.detail, function(text)
                    return (text or "") ~= ""
                end),
            })
    end

    node.children = { column { align_h = "center", align_v = "center", spacing = theme.spacing.xs, children = lines } }
    return rect(node)
end
