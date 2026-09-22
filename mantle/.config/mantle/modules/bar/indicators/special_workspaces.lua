local theme = require("config.theme")
local util = require("lib.util")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")

local SLOT = "special_workspaces"
local hovered_name = state("special_workspace_tooltip", "")
-- The row is one hover slot, so the card would point at the middle of the group.
local hovered_anchor = util.hover_anchor(hovered_name, "special-")

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
    local short = short_name(name)
    local letters = #short > 2 and short:sub(1, 2):upper() or short:upper()
    -- `ground` already folds the pointer in, so it is both states.
    return icon_button(letters, function()
        mantle.workspaces:invoke("toggle_special", name)
    end, {
        slot = "special-" .. name,
        art = icon_name,
        art_size = theme.icon.md,
        icon_size = theme.font.xs,
        width = theme.item_width,
        radius = theme.item_radius,
        background = ground,
        background_hover = ground,
        on_hover = function(is_hovered)
            if is_hovered then
                hovered_name:set(name)
            elseif hovered_name:get() == name then
                hovered_name:set("")
            end
        end,
    })
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

local special_tooltip = tooltip({
    id = "special_workspaces_tooltip",
    slot = SLOT,
    anchor = hovered_anchor,
    text = hovered_name:map(function(name)
        return capitalize(short_name(name))
    end),
})

return { indicator = indicator, tooltip = special_tooltip }
