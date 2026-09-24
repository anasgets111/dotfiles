local theme = require("config.theme")
local cell = require("components.cell")
local glyph = require("components.glyph")
local spinner = require("components.spinner")
local util = require("lib.util")

---@class PanelToggleCardOpts
---@field slot string The hover region's name; one per tile.
---@field icon? string|Bound Omitted draws the label alone.
---@field label string|Bound
---@field detail? string|Bound A second line, hidden while empty.
---@field signal Signal The capability whose payload `read` inspects.
---@field read fun(payload: any): boolean
---@field spinning? Signal Replaces the icon while an action runs.
---@field on_change fun(checked: boolean)
---@field disabled? Signal The tile dims and ignores clicks, for hardware that is not there.

---@param opts PanelToggleCardOpts
return function(opts)
    local hovered = hover(opts.slot)
    local checked = opts.signal:map(function(value)
        return util.read_bool(value, opts.read)
    end)

    local tint = util.tint(checked, hovered)
    local ink = tint(theme.ACCENT, theme.ACCENT, theme.FG, theme.DIM)

    ---@type string|TextRun[]|Bound
    local label_content
    local label = opts.label
    if type(label) == "userdata" then
        ---@cast label Signal
        label_content = computed({ checked, label }, function(on, text_value)
            return { { text = text_value or "", bold = on } }
        end)
    else
        label_content = checked:map(function(on)
            return { { text = label, bold = on } }
        end)
    end

    local lines = {}
    if opts.icon ~= nil and opts.icon ~= "" then
        local icon = glyph(opts.icon, ink, theme.icon.md, {
            align = "Center",
            visible = opts.spinning and opts.spinning:map(function(on)
                return not on
            end),
            animate = { foreground = theme.animation_ms },
        })
        lines[1] = opts.spinning and rect {
            width = theme.icon.md,
            height = theme.icon.md,
            align_h = "Center",
            align_v = "Center",
            children = { icon, spinner(opts.spinning, theme.icon.md, ink) },
        } or icon
    end
    lines[#lines + 1] = cell(label_content, ink, theme.font.xs, {
        align = "Center",
        animate = { foreground = theme.animation_ms },
    })
    if opts.detail ~= nil then
        lines[#lines + 1] = cell(opts.detail, tint(theme.TEXT_ACTIVE, theme.TEXT_ACTIVE, theme.TEXT_ACTIVE, theme.DIM),
            theme.font.xs, {
                align = "Center",
                align_v = "Center",
                visible = util.lift(opts.detail, function(text)
                    return (text or "") ~= ""
                end),
            })
    end

    return button {
        width = "Fill",
        height = theme.panel_toggle_height,
        radius = theme.radius.lg,
        hover = hovered,
        background = tint(theme.ACCENT_LIGHT, theme.ACCENT_SUBTLE, theme.GLASS_HOVER, theme.GLASS_CONTENT),
        border_width = theme.border_width,
        border_color = tint(theme.ACCENT_MEDIUM, theme.ACCENT_MEDIUM, theme.GLASS_BORDER_HOVER, theme.GLASS_BORDER),
        opacity = opts.disabled and opts.disabled:map(function(off)
            return off and theme.opacity.disabled or 1
        end),
        animate = {
            background = theme.animation_ms,
            border_color = theme.animation_ms,
            opacity = { duration = theme.animation_ms, easing = "OutCubic" },
        },
        on_click = function(_, mouse_button)
            if mouse_button ~= "left" or (opts.disabled and opts.disabled:get()) then
                return
            end
            opts.on_change(not util.read_bool(opts.signal:get(), opts.read))
        end,
        children = { column { align_h = "Center", align_v = "Center", spacing = theme.spacing.xs, children = lines } },
    }
end
