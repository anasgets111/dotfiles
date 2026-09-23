local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local tooltip = require("components.tooltip")
local tray_menu = require("modules.bar.panels.tray_menu")

local SCROLL = scroll("sys_tray")
local SLOT = "sys_tray"
local hovered_id = state("sys_tray_tooltip", "")

-- `name` is SNI `Title`, which senders fill with a widget id (`vesktop_status_icon_1`). Strip that
-- and ask `applications` for the installed name.
-- ponytail: a suffix match. An id shaped differently keeps whatever the sender wrote.
local function item_label(item, applications)
    local base = (item.name or ""):gsub("[_%-]?status[_%-]?icon[_%-]?%d*$", "")
    local entry = util.app_entry(applications, base) or util.app_entry(applications, item.name)
    return (entry and entry.name) or (base ~= "" and base) or item.id or "Tray item"
end

-- The hovered item's two lines. `said` is the sender's own `ToolTip` -- the name again for some
-- ("Vesktop"), live state for others ("DL speed: 0 B/s") -- kept only when it adds something.
local hovered = computed({ util.hold(hovered_id), mantle.tray, mantle.applications }, function(id, tray, applications)
    local found
    for _, item in ipairs((tray and tray.items) or {}) do
        if item.id == id then
            found = item
        end
    end
    local label = found and item_label(found, applications) or (id ~= "" and id or "Tray item")
    local said = (found and found.tooltip) or ""
    return { label = label, said = not said:lower():find(label:lower(), 1, true) and said or "" }
end)

-- Hide `Passive`: the spec treats it as no presentation, so disabling an application's tray icon
-- removes it.
local function items_of(t)
    local out = {}
    for _, item in ipairs((t and t.items) or {}) do
        if item.status ~= "Passive" then
            out[#out + 1] = item
        end
    end
    return out
end

-- `NeedsAttention` uses supplied attention artwork. Telegram instead rewrites `icon_name` to
-- `-attention-symbolic`, so fallback to the base pair rather than drawing nothing.
local function artwork(item)
    if item.status == "NeedsAttention" and (item.attention_icon_name or item.attention_icon_path) then
        return item.attention_icon_name or item.attention_icon_path
    end
    return item.icon_name or item.icon_path
end

-- One slot per item, the icon plus `spacing.sm`; equal slots keep the row even under fallback
-- letters.
local ITEM_WIDTH = theme.icon.md + theme.spacing.sm

-- The ceiling, not the width: six items fit, more scroll instead of taking the zone. This
-- `row` does not shrink children, so it needs a cap.
local TRAY_WIDTH = 6 * ITEM_WIDTH

local has_items = util.shown_when(mantle.tray, function(t)
    return #items_of(t) > 0
end)

-- No `width`: the row measures its own children and stops at `max_width`, equivalent to
-- `min(count * ITEM_WIDTH, TRAY_WIDTH)`, with `spacing = 0` and every child a fixed `ITEM_WIDTH`.
local items = list {
    max_width = TRAY_WIDTH,
    -- Full height: a content-height row hangs the card 8px above every other tooltip's, and gives
    -- the pointer a shorter target.
    height = "Fill",
    direction = "Horizontal",
    spacing = 0,
    align_v = "Center",
    scroll = SCROLL,
    visible = has_items,
    source = computed({ mantle.tray, mantle.applications }, items_of),
    itemfn = function(item)
        local item_slot = SLOT .. "-" .. tostring(item.id)
        local item_hovered = hover(item_slot)
        local entry = util.app_entry(mantle.applications:get(), item.name or item.id)
        local art = artwork(item) or (entry and entry.icon)
        local face
        if art then
            -- Without `align_h`, artwork sits at the square's left edge and the first icon lands
            -- under the pill's corner radius.
            face = icon {
                name = art,
                size = theme.icon.md,
                align_h = "Center",
                align_v = "Center",
                foreground = theme.FG,
            }
        else
            -- No artwork happens. Two 9px `DIM` letters beside 22px glyphs read as a rendering
            -- fault, so match the icon weight.
            face = cell((item.name or item.id or "?"):sub(1, 2), theme.FG, theme.font.sm,
                { align = "Center", align_v = "Center" })
        end
        -- Right opens a menu, left activates, middle is secondary activation. `item_is_menu` makes
        -- a left click open the menu instead of becoming a no-op.
        return button {
            width = ITEM_WIDTH,
            height = "Fill",
            align_v = "Center",
            hover = item_hovered,
            on_hover = util.track_hover(hovered_id, item.id),
            on_click = function(rect_, mouse_button)
                local wants_menu = mouse_button == "right" or item.item_is_menu
                if wants_menu and item.menu ~= nil then
                    tray_menu.open(item, rect_)
                elseif mouse_button == "left" then
                    mantle.tray:invoke("activate", item.id, 0, 0)
                elseif mouse_button == "middle" then
                    mantle.tray:invoke("secondary_activate", item.id, 0, 0)
                end
            end,
            -- The item decides what a notch means; ours uses the vertical axis, the only one
            -- `on_wheel` reports.
            on_wheel = function(_, notches)
                mantle.tray:invoke("scroll", item.id, math.floor(notches), "vertical")
            end,
            children = { face },
        }
    end,
    key = function(item)
        return tostring(item.id)
    end,
}

-- `cell` takes no opacity, so the muted level is folded into the colour.
local empty_label = cell("No tray items", theme.with_opacity(theme.DIM, theme.opacity.muted), theme.font.xs, {
    align_v = "Center",
    visible = has_items:map(function(any)
        return not any
    end),
})

local indicator = row {
    height = theme.item_height,
    align_v = "Center",
    hover = hover(SLOT),
    radius = theme.item_radius,
    background = theme.GLASS_CONTROL,
    border_width = theme.border_width,
    border_color = theme.GLASS_BORDER,
    -- Both children stay here; an invisible one takes no width, position or gap, so the pill
    -- measures whichever is showing.
    children = { items, empty_label },
}

local tray_tooltip = tooltip({
    id = "sys_tray_tooltip",
    slot = SLOT,
    group = hovered_id,
    group_prefix = SLOT .. "-",
    text = hovered:map(function(lines) return lines.label end),
    detail = hovered:map(function(lines) return lines.said end),
})

return { indicator = indicator, tooltip = tray_tooltip }
