-- `cell` in `theme.icon_font`, with `cell`'s signature. The family must be named. The `Mono` face fits
-- each private-use glyph into one cell, and the chain's `Propo` face spaces and sizes them differently
-- at the same `theme.icon.*`.
local cell = require("components.cell")
local theme = require("config.theme")
local util = require("lib.util")

---@param content string|Bound
---@param color? Color|Bound
---@param size? integer
---@param opts? { width?: integer|"Fill", align?: "Start"|"Center"|"End", align_v?: "Start"|"Center"|"End", visible?: boolean|Bound, wrap?: "None"|"Word"|Bound, max_lines?: integer|Bound, on_link?: fun(href: string), animate?: TextAnimations|Bound }
return function(content, color, size, opts)
    return cell(content, color, size, util.with(opts, "font", theme.icon_font))
end
