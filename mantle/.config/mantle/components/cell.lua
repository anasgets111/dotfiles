-- Shared text cell with default size and weight. `elide = "End"` only cuts a bounded `opts.width`:
-- character counts are the wrong unit, since "WWWWW" and "iiiii" differ in width. `opts.wrap` moves
-- the ellipsis to the last of `opts.max_lines`; off by default, as a second line grows bar slots.
-- `opts.align` sets both `text_align` (inside the cell) and `align_h` (a content-sized box in a
-- stacking parent or `column`; `row` ignores it). `text_align` alone leaves the box at x=0.
local theme = require("config.theme")

-- Last hop before `text.content`: a `list` `itemfn` is typed `fun(item: any)`, so a raw span array
-- could reach `content` and freeze the shell on its last good scene. Image spans are not text;
-- `notifications.notification_body` converts them.
---@param content string|TextRun[]|Bound
---@param color? Color|Bound
---@param size? integer
---@param opts? { width?: integer|"Fill", align?: "Start"|"Center"|"End", align_v?: "Start"|"Center"|"End", visible?: boolean|Bound, wrap?: "None"|"Word"|Bound, max_lines?: integer|Bound, on_link?: fun(href: string), font?: string|Bound, animate?: Animations|Bound }
return function(content, color, size, opts)
    opts = opts or {}
    return text {
        content = content,
        foreground = color or theme.FG,
        font_size = size or theme.font.md,
        font = opts.font,
        width = opts.width,
        align_v = opts.align_v,
        align_h = opts.align,
        visible = opts.visible,
        text_align = opts.align,
        elide = "End",
        wrap = opts.wrap,
        max_lines = opts.max_lines,
        on_link = opts.on_link,
        animate = opts.animate,
    }
end
