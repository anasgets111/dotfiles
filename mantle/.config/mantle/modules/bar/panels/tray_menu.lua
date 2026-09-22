-- The DBusMenu attached to a tray icon, opened by right-clicking it. `mantle.tray` carries the whole
-- tree from one `GetLayout(0, -1)` at registration, so a submenu needs no `tray:menu_will_show`
-- round trip; that command stays for applications that populate menus lazily.
--
-- Submenus expand in place, since a popup per submenu would be a surface per level. Depth follows
-- the application up to the Supervisor's `MAX_MENU_DEPTH`; rows flatten the tree.
local theme = require("config.theme")
local cell = require("components.cell")
local ui_state = require("lib.ui_state")

local KIND = "tray_menu"

-- Every tray item shares one card and one `panel_host` section, so its id travels beside
-- `panel_kind`. `expanded` is a set of open submenu ids, keeping descendants when an ancestor
-- collapses.
local item_id = state("tray_menu_item", "")

local expanded = state("tray_menu_expanded", {})

-- `components/panel_action_icon.lua` uses the same literal for the same reason.
local CLEAR = "#00000000"

local INDENT = theme.spacing.md

local function menu_of(t, id)
    for _, item in ipairs((t and t.items) or {}) do
        if item.id == id then
            return item.menu
        end
    end
    return nil
end

-- Flatten depth-first so `list` gets one row shape and carries each row's indent.
local function flatten(entries, depth, open, out)
    for _, entry in ipairs(entries or {}) do
        out[#out + 1] = { entry = entry, depth = depth }
        if #(entry.children or {}) > 0 and open[tostring(entry.id)] then
            flatten(entry.children, depth + 1, open, out)
        end
    end
end

local rows = computed({ mantle.tray, item_id, expanded }, function(t, id, open)
    local out = {}
    flatten(menu_of(t, id), 0, open or {}, out)
    return out
end)

-- Three plain-character markers, not glyphs from `config/icons.lua`, preserve what the
-- application's toolkit would draw.
local SUBMENU = "\u{203A}"
local CHECKED = "\u{2713}"
local SELECTED = "\u{25CF}"

-- A submenu marker takes priority over a toggle's check mark; off and indeterminate toggles draw
-- nothing.
local function marker(entry)
    if #(entry.children or {}) > 0 then
        return SUBMENU
    end
    if entry.toggle_state ~= 1 then
        return ""
    end
    return entry.toggle_type == "radio" and SELECTED or CHECKED
end

-- DBusMenu marks a mnemonic with `_`, so `"_Quit"` arrives with the underscore. This panel takes no
-- keyboard focus, and advertising an accelerator that does nothing is worse than omitting it, so the
-- marker is dropped; underline it once the key works. `__` is its escape for a real underscore.
---@param label string?
---@return string
local function strip_mnemonics(label)
    return ((label or ""):gsub("__", "\0"):gsub("_", ""):gsub("%z", "_"))
end

local function activate(entry)
    if #(entry.children or {}) > 0 then
        local open = expanded:get() or {}
        local next_open = {}
        for key, value in pairs(open) do
            next_open[key] = value
        end
        local key = tostring(entry.id)
        next_open[key] = not open[key] or nil
        expanded:set(next_open)
        return
    end
    -- Draw disabled entries so the application's layout survives; the Supervisor refuses their
    -- action anyway.
    if entry.enabled then
        mantle.tray:invoke("activate_menu_item", item_id:get(), entry.id)
    end
    ui_state.close_panel()
end

local function row_for(row_entry)
    local entry = row_entry.entry
    local pad = theme.spacing.sm + row_entry.depth * INDENT
    if entry.menu_type == "separator" then
        return rect {
            width = "Fill",
            height = theme.spacing.sm,
            children = {
                rect {
                    width = "Fill",
                    height = theme.border_width,
                    align_v = "Center",
                    background = theme.BORDER,
                    margin = { left = pad, right = theme.spacing.sm },
                },
            },
        }
    end
    local slot = "tray-menu-" .. tostring(entry.id)
    local hovered = hover(slot)
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
        height = theme.item_height,
        radius = theme.item_radius,
        hover = hovered,
        -- `color: containsMouse ? glassControlHoverColor : "transparent"`, so use transparent, not
        -- `nil`.
        background = hovered:map(function(on)
            return on and theme.GLASS_CONTROL_HOVER or CLEAR
        end),
        -- Opacity applies to the row, dimming icon and word.
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

local function menu_list(id)
    return list {
        id = "tray-menu-" .. tostring(id),
        width = "Fill",
        spacing = 0,
        source = rows,
        itemfn = row_for,
        -- Depth is part of the key: the same entry drawn at two levels is two rows, and reconciling
        -- them by id alone would reuse one node for both.
        key = function(row_entry)
            return tostring(row_entry.entry.id) .. ":" .. tostring(row_entry.depth)
        end,
    }
end

local body = item_id:map(function(id)
    return { menu_list(id) }
end)

---Show `item`'s menu, anchored under its icon.
---@param item TrayItem
---@param anchor Rect
local function open(item, anchor)
    item_id:set(item.id)
    expanded:set({})
    ui_state.open_panel(KIND, anchor)
end

return { kind = KIND, body = body, open = open }
