-- Section headers and rows share a scroll area whose height ends between whole rows.
local theme = require("config.theme")
local util = require("lib.util")

---@param source Signal<table[]>
---@param name string Scroll state name.
---@param itemfn fun(item: table): Node
---@param visible? boolean|Bound
---@return Node
return function(source, name, itemfn, visible)
    return list {
        width = "fill",
        spacing = theme.spacing.xs,
        scroll = scroll(name),
        animate = { scroll = theme.scroll_ease },
        visible = visible,
        max_height = source:map(function(items)
            return util.fit_height(items, theme.panel_list_height, theme.spacing.xs, function(item)
                return item.kind == "header" and theme.section_header_height or theme.control.lg
            end)
        end),
        source = source,
        itemfn = itemfn,
        key = function(item)
            return item.key
        end,
    }
end
