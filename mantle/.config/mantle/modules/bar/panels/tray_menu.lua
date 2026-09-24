-- A tray icon's DBusMenu, opened by right-clicking it. `mantle.tray` carries the whole tree from one
-- `GetLayout(0, -1)` at registration, so a submenu needs no `tray:menu_will_show` round trip. That
-- command stays for applications that populate menus lazily.
--
-- Submenus expand in place, since a popup per submenu would be a surface per level. Depth follows
-- the application up to the Supervisor's `MAX_MENU_DEPTH`.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local divider = require("components.divider")
local ui_state = require("lib.ui_state")

local KIND = "tray_menu"

-- Every tray item shares one card and one `panel_host` section, so its id travels beside
-- `panel_kind`. `expanded` is a set of open submenu ids, so descendants stay open when an ancestor
-- collapses.
local item_id = state("tray_menu_item", "")
local expanded = state("tray_menu_expanded", {})

local function menu_of(tray, id)
    for _, item in ipairs((tray and tray.items) or {}) do
        if item.id == id then
            return item.menu
        end
    end
end

-- Depth-first, so `list` gets one row shape that carries its indent.
local function flatten(entries, depth, open, out)
    for _, entry in ipairs(entries or {}) do
        out[#out + 1] = { entry = entry, depth = depth }
        if #(entry.children or {}) > 0 and open[tostring(entry.id)] then
            flatten(entry.children, depth + 1, open, out)
        end
    end
end

local rows = computed({ mantle.tray, item_id, expanded }, function(tray, id, open)
    local out = {}
    flatten(menu_of(tray, id), 0, open, out)
    return out
end)

-- Plain characters, not `config/icons.lua` glyphs, draw what the application's toolkit would. A
-- submenu marker outranks a check mark; off and indeterminate toggles draw nothing.
local function marker(entry)
    if #(entry.children or {}) > 0 then
        return "\u{203A}"
    end
    if entry.toggle_state ~= 1 then
        return ""
    end
    return entry.toggle_type == "radio" and "\u{25CF}" or "\u{2713}"
end

-- DBusMenu marks a mnemonic with `_`, so `"_Quit"` arrives with the underscore. This panel takes no
-- keyboard focus, and an accelerator that does nothing is worse than none, so the marker goes.
-- Underline it once the key works. `__` escapes a real underscore.
local function strip_mnemonics(label)
    return ((label or ""):gsub("__", "\0"):gsub("_", ""):gsub("%z", "_"))
end

local function activate(entry)
    if #(entry.children or {}) > 0 then
        local open = expanded:get()
        local key = tostring(entry.id)
        expanded:set(util.with(open, key, not open[key] or nil))
        return
    end
    -- Disabled entries are drawn so the application's layout survives, and a click on one does
    -- nothing rather than closing the menu.
    if entry.enabled then
        mantle.tray:activate_menu_item(item_id:get(), entry.id)
        ui_state.close_panel()
    end
end

local SEPARATOR_HEIGHT = theme.spacing.sm

local function row_for(row_entry)
    local entry = row_entry.entry
    local pad = theme.spacing.sm + row_entry.depth * theme.spacing.md
    if entry.menu_type == "separator" then
        return rect {
            width = "Fill",
            height = SEPARATOR_HEIGHT,
            children = { divider { margin = { left = pad, right = theme.spacing.sm } } },
        }
    end
    local hovered = hover("tray-menu-" .. tostring(entry.id))
    local children = {}
    if entry.icon_name then
        children[#children + 1] = icon {
            name = entry.icon_name,
            size = theme.icon.sm,
            align_v = "Center",
            foreground = theme.FG,
        }
    end
    children[#children + 1] = cell(strip_mnemonics(entry.label), theme.FG, theme.font.sm, {
        width = "Fill",
        align_v = "Center",
    })
    local trailing = marker(entry)
    if trailing ~= "" then
        children[#children + 1] = cell(trailing, theme.FG, theme.font.sm, { align_v = "Center" })
    end
    return button {
        width = "Fill",
        height = theme.control.md,
        radius = theme.radius.md,
        hover = hovered,
        -- `panel_row`'s hover, so a menu reads like the panels it opens beside.
        background = hovered:map(function(on)
            return on and theme.GLASS_HOVER or theme.CLEAR
        end),
        opacity = entry.enabled and 1 or theme.opacity.disabled,
        on_click = function(_, mouse_button)
            if mouse_button == "left" then
                activate(entry)
            end
        end,
        children = { row {
            width = "Fill",
            height = "Fill",
            align_v = "Center",
            spacing = theme.spacing.sm,
            padding = { left = pad, right = theme.spacing.sm },
            children = children,
        } },
    }
end

local body = item_id:map(function(id)
    return { list {
        id = "tray-menu-" .. tostring(id),
        width = "Fill",
        spacing = 0,
        max_height = rows:map(function(list)
            return util.fit_height(list, theme.tray_menu_height, 0, function(row_entry)
                return row_entry.entry.menu_type == "separator" and SEPARATOR_HEIGHT or theme.control.md
            end)
        end),
        scroll = scroll("tray_menu"),
        source = rows,
        itemfn = row_for,
        -- Depth is part of the key: the same entry drawn at two levels is two rows, and reconciling
        -- them by id alone would reuse one node for both.
        key = function(row_entry)
            return tostring(row_entry.entry.id) .. ":" .. tostring(row_entry.depth)
        end,
    } }
end)

-- `item`'s menu, anchored under its icon. The same icon again closes it, like every other panel.
local function open(item, anchor)
    if ui_state.panel_is(KIND) and item_id:get() == item.id then
        return ui_state.close_panel()
    end
    item_id:set(item.id)
    expanded:set({})
    ui_state.open_panel(KIND, anchor)
end

return { kind = KIND, body = body, open = open }
