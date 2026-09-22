local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local tooltip = require("components.tooltip")

local SLOT = "special_workspaces"
local hovered_name = state("special_workspace_tooltip", "")

local function specials_of(w)
    return (w and w.special) or {}
end

local function short_name(name)
    return name:gsub("^special:?", "")
end

local function capitalize(name)
    return name ~= "" and name:sub(1, 1):upper() .. name:sub(2) or "Special workspace"
end

local function special_button(special)
    local name = special.name
    local entry = mantle.workspaces:map(function(w)
        for _, candidate in ipairs(specials_of(w)) do
            if candidate.name == name then
                return candidate
            end
        end
        return special
    end)
    local is_shown = entry:map(function(current)
        return current.shown_on ~= nil
    end)
    local slot_hovered = hover("special-" .. name)
    local ground = computed({ is_shown, slot_hovered }, function(shown, is_hovered)
        if shown then
            return theme.ACCENT
        end
        return is_hovered and theme.GLASS_CONTROL_HOVER or theme.GLASS_CONTROL
    end)
    local icon_name = computed({ mantle.applications, entry }, function(applications, current)
        local app = util.app_entry(applications, current.app_id)
        return (app and app.icon) or ""
    end)
    local has_icon = icon_name:map(function(icon)
        return icon ~= ""
    end)
    local short = short_name(name)
    local letters = #short > 2 and short:sub(1, 2):upper() or short:upper()
    return button {
        width = theme.item_width,
        height = theme.item_height,
        align_v = "Center",
        radius = theme.item_radius,
        hover = slot_hovered,
        on_hover = function(is_hovered)
            if is_hovered then
                hovered_name:set(name)
            elseif hovered_name:get() == name then
                hovered_name:set("")
            end
        end,
        background = ground,
        border_width = theme.border_width,
        border_color = slot_hovered:map(function(is_hovered)
            return is_hovered and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER
        end),
        children = {
            icon {
                name = icon_name,
                size = theme.icon.md,
                align_h = "Center",
                align_v = "Center",
                visible = has_icon,
            },
            cell(letters, ground:map(theme.text_contrast), theme.font.xs, {
                align = "Center",
                align_v = "Center",
                visible = has_icon:map(function(shown)
                    return not shown
                end),
            }),
        },
        on_click = function(_, mouse_button)
            if mouse_button ~= "left" then
                return
            end
            mantle.workspaces:invoke("toggle_special", name)
        end,
    }
end

local indicator = row {
    height = theme.item_height,
    align_v = "Center",
    hover = hover(SLOT),
    visible = mantle.workspaces:map(function(w)
        return #specials_of(w) > 0
    end),
    children = {
        list {
            direction = "Horizontal",
            spacing = theme.spacing.sm,
            align_v = "Center",
            source = mantle.workspaces:map(specials_of),
            itemfn = special_button,
            key = function(special)
                return special.name
            end,
        },
    },
}

local special_tooltip = tooltip({ id = "special_workspaces_tooltip", slot = SLOT, text = hovered_name:map(function(name)
    return capitalize(short_name(name))
end) })

return { indicator = indicator, tooltip = special_tooltip }
