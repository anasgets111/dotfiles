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
    local detail_visible
    local wide
    if type(detail) == "userdata" then
        ---@cast detail Signal
        detail_visible = util.shown_when(detail, function(text)
            return text ~= ""
        end)
        wide = computed({ size, detail_visible }, function(rect, shown)
            return shown and rect ~= nil and (rect.width or 0) >= theme.panel_toggle_compact_threshold
        end)
    else
        detail_visible = type(detail) == "string" and detail ~= ""
        wide = size:map(function(rect)
            return detail_visible and rect ~= nil and (rect.width or 0) >= theme.panel_toggle_compact_threshold
        end)
    end

    local ground = computed({ checked, hovered }, function(on, hot)
        if on then
            return hot and theme.ACCENT_LIGHT or theme.ACCENT_SUBTLE
        end
        return hot and theme.GLASS_HOVER or theme.GLASS_CONTENT
    end)
    local ring = computed({ checked, hovered }, function(on, hot)
        if on then
            return theme.ACCENT_MEDIUM
        end
        return hot and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER
    end)
    local ink = computed({ checked, hovered }, function(on, hot)
        if on then
            return theme.ACCENT
        end
        return hot and theme.FG or theme.DIM
    end)

    ---@type string|TextRun[]|Bound
    local label_content
    if type(opts.label) == "userdata" then
        local label = opts.label
        ---@cast label Signal
        label_content = computed({ checked, label }, function(on, text_value)
            return { { text = text_value or "", bold = on } }
        end)
    else
        label_content = checked:map(function(on)
            return { { text = opts.label, bold = on } }
        end)
    end

    local function icon_node()
        if opts.icon == nil or opts.icon == "" then
            return nil
        end
        return glyph(opts.icon, ink, theme.icon.md, {
            align = "Center",
            animate = { foreground = theme.animation_ms },
        })
    end

    local function label_node()
        return cell(label_content, ink, theme.font.xs, {
            align = "Center",
            animate = { foreground = theme.animation_ms },
        })
    end

    local detail_ink = computed({ checked, hovered }, function(on, hot)
        return (on or hot) and theme.TEXT_ACTIVE or theme.DIM
    end)

    local function detail_node(wide_mode)
        return cell(detail, detail_ink, theme.font.xs, {
            width = wide_mode and "Fill" or nil,
            align = wide_mode and nil or "Center",
            align_v = "Center",
            visible = detail_visible,
        })
    end

    local function leading_nodes()
        local leading = {}
        local icon = icon_node()
        if icon then
            leading[#leading + 1] = icon
        end
        leading[#leading + 1] = label_node()
        return leading
    end

    local function compact_layout()
        local lines = leading_nodes()
        if opts.detail ~= nil then
            lines[#lines + 1] = detail_node(false)
        end
        return column {
            align_h = "Center",
            align_v = "Center",
            spacing = theme.spacing.xs,
            children = lines,
        }
    end

    local function wide_layout()
        return row {
            width = "Fill",
            align_v = "Center",
            spacing = theme.spacing.sm,
            children = {
                column { align_h = "Center", align_v = "Center", children = leading_nodes() },
                detail_node(true),
            },
        }
    end

    return button {
        width = "Fill",
        height = opts.height or theme.panel_toggle_height,
        radius = theme.radius.lg,
        hover = hovered,
        background = ground,
        border_width = theme.border_width,
        border_color = ring,
        opacity = opts.disabled and opts.disabled:map(function(off)
            return off and theme.opacity.disabled or 1
        end) or nil,
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
            return { is_wide and wide_layout() or compact_layout() }
        end),
    }
end
