local theme = require("config.theme")
local util = require("lib.util")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")

local SLOT = "special_workspaces"
local hovered_name = state("special_workspace_tooltip", "")

local function specials_of(workspaces)
    return (workspaces and workspaces.special) or {}
end

local function short_name(name)
    return name:gsub("^special:?", "")
end

local function special_button(special)
    local name = special.name
    local entry = util.live_entry(mantle.workspaces, specials_of, special, "name")
    local ground = computed({ entry, hover("special-" .. name) }, function(current, is_hovered)
        if current.shown_on ~= nil then
            return theme.ACCENT
        end
        return is_hovered and theme.GLASS_CONTROL_HOVER or theme.GLASS_CONTROL
    end)
    -- `ground` already folds the pointer in, so it is both states.
    return icon_button(short_name(name):sub(1, 2):upper(), function()
        mantle.workspaces:invoke("toggle_special", name)
    end, {
        slot = "special-" .. name,
        art = util.app_icon(entry),
        icon_size = theme.font.sm,
        radius = theme.item_radius,
        background = ground,
        background_hover = ground,
        on_hover = util.track_hover(hovered_name, name),
    })
end

local indicator = row {
    height = theme.item_height,
    align_v = "Center",
    hover = hover(SLOT),
    visible = mantle.workspaces:map(function(workspaces)
        return #specials_of(workspaces) > 0
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
    group = hovered_name,
    group_prefix = "special-",
    text = util.hold(hovered_name):map(function(name)
        local short = short_name(name)
        return short ~= "" and short:sub(1, 1):upper() .. short:sub(2) or "Special workspace"
    end),
})

return { indicator = indicator, tooltip = special_tooltip }
