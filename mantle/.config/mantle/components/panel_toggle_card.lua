local theme = require("config.theme")
local cell = require("components.cell")
local glyph = require("components.glyph")
local util = require("lib.util")

---@class PanelToggleCardOpts
---@field slot string The hover region's name; one per tile.
---@field icon? string|Bound Omitted draws the label alone. A group whose options have no glyph -- the recorder's frame rates -- needs no empty line; a missing line is the same intent.
---@field height? integer The tile's height. Default `theme.panel_toggle_height`, which is the radio pair in the power menu; a four-across settings group is `control.lg`.
---@field label string|Bound
---@field detail? string|Bound A second line, hidden while empty.
---@field signal Signal The capability whose payload `read` inspects.
---@field read fun(payload: any): boolean
---@field on_change fun(checked: boolean)
---@field disabled? Signal The tile dims and ignores clicks, for hardware that is not there.

---@param opts PanelToggleCardOpts
return function(opts)
    local hovered = hover(opts.slot)
    local size = geometry("panel-toggle-" .. opts.slot)
    local checked = opts.signal:map(function(value)
        return util.read_bool(value, opts.read)
    end)
    ---@type string|Signal
    local detail = opts.detail or ""
    ---@type boolean|Signal
    local detail_visible = detail ~= ""
    local function fits(rect)
        return rect ~= nil and (rect.width or 0) >= theme.panel_toggle_compact_threshold
    end
    local wide
    if type(detail) == "userdata" then
        ---@cast detail Signal
        detail_visible = util.shown_when(detail, function(text)
            return text ~= ""
        end)
        wide = computed({ size, detail_visible }, function(rect, shown)
            return shown and fits(rect)
        end)
    else
        wide = size:map(function(rect)
            return detail_visible and fits(rect)
        end)
    end

    -- Checked picks the first pair, unchecked the second; each pair is hovered, then resting.
    local function tint(on_hot, on_rest, hot, rest)
        return computed({ checked, hovered }, function(on, is_hot)
            if on then
                return is_hot and on_hot or on_rest
            end
            return is_hot and hot or rest
        end)
    end
    local ink = tint(theme.ACCENT, theme.ACCENT, theme.FG, theme.DIM)
    local detail_ink = tint(theme.TEXT_ACTIVE, theme.TEXT_ACTIVE, theme.TEXT_ACTIVE, theme.DIM)

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

    local function leading_nodes()
        local leading = {}
        if opts.icon ~= nil and opts.icon ~= "" then
            leading[1] = glyph(opts.icon, ink, theme.icon.md, {
                align = "Center",
                animate = { foreground = theme.animation_ms },
            })
        end
        leading[#leading + 1] = cell(label_content, ink, theme.font.xs, {
            align = "Center",
            animate = { foreground = theme.animation_ms },
        })
        return leading
    end

    local function detail_node(wide_mode)
        return cell(detail, detail_ink, theme.font.xs, {
            width = wide_mode and "Fill" or nil,
            align = wide_mode and nil or "Center",
            align_v = "Center",
            visible = detail_visible,
        })
    end

    return button {
        width = "Fill",
        height = opts.height or theme.panel_toggle_height,
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
        children = wide:map(function(is_wide)
            if is_wide then
                return { row {
                    width = "Fill",
                    align_v = "Center",
                    spacing = theme.spacing.sm,
                    children = {
                        column { align_h = "Center", align_v = "Center", children = leading_nodes() },
                        detail_node(true),
                    },
                } }
            end
            local lines = leading_nodes()
            if opts.detail ~= nil then
                lines[#lines + 1] = detail_node(false)
            end
            return { column { align_h = "Center", align_v = "Center", spacing = theme.spacing.xs, children = lines } }
        end),
    }
end
