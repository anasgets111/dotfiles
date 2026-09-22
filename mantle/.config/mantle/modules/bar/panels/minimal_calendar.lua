-- Current month grid with today marked: `os.date`/`os.time` arithmetic with `mantle.system.time`
-- supplying *today*, so it needs no calendar capability and none should be added.
--
-- Not a panel. It sits in the clock's hover tooltip, owned by `modules/bar/indicators/date_time.lua`.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")

local COLUMNS = 7
local DAY_NAMES = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }

-- Square day cells keep the grid calendar-like.
local DAY_SIDE = theme.s(30, 24)

-- Where the month starts in the week and how long it is. Lua's normalizing `os.time` makes `day = 0`
-- the previous month's last day, avoiding a month-length table and a leap-year branch.
local function month_of(now)
    local today = os.date("*t", now)
    local first = os.date("*t", os.time({ year = today.year, month = today.month, day = 1, hour = 12 }))
    -- `wday` is 1-based from Sunday, matching `DAY_NAMES`.
    local lead = first.wday - 1
    local days_in_month = os.date("*t", os.time({ year = today.year, month = today.month + 1, day = 0, hour = 12 })).day
    return today, lead, days_in_month
end

-- Four to six rows: fixed six-week sizing would leave blank cells in short months, making the
-- tooltip too tall for its contents.
local function rows_in(now)
    local _, lead, days_in_month = month_of(now)
    return math.ceil((lead + days_in_month) / COLUMNS)
end

-- `rows_in * COLUMNS` entries in reading order; leading blanks are `nil`, so the first week uses
-- the same loop as the rest. Trailing blanks exist only inside the last week the month reaches.
local function month_grid(now)
    local today, lead, days_in_month = month_of(now)
    local cells = {}
    for index = 1, rows_in(now) * COLUMNS do
        local day = index - lead
        cells[index] = {
            index = index,
            day = (day >= 1 and day <= days_in_month) and day or nil,
            is_today = day == today.day,
            -- `DAY_NAMES` is 1-based from Sunday, so the last column is Saturday. The heading marks
            -- it, and each day cell in that column marks itself the same way.
            is_saturday = (index - 1) % COLUMNS == COLUMNS - 1,
        }
    end
    return cells
end

local function day_cell(entry)
    if entry.day == nil then
        -- Keep the blank in its column; an absent child would shift the week left.
        return rect { width = DAY_SIDE, height = DAY_SIDE }
    end
    return rect {
        width = DAY_SIDE,
        height = DAY_SIDE,
        radius = DAY_SIDE / 2,
        background = entry.is_today and theme.ACCENT or nil,
        children = {
            -- Today is the one date read at a glance, so it carries the weight as well as the disc.
            cell({ { text = tostring(entry.day), bold = entry.is_today } },
                entry.is_today and theme.text_contrast(theme.ACCENT)
                or entry.is_saturday and theme.text_contrast(theme.BG)
                or theme.FG,
                theme.font.sm, { width = "Fill", align = "Center", align_v = "Center" }),
        },
    }
end

local function week_rows(now)
    local cells = month_grid(now)
    local rows = {}
    for week = 0, rows_in(now) - 1 do
        local days = {}
        for column = 1, COLUMNS do
            days[column] = day_cell(cells[week * COLUMNS + column])
        end
        rows[#rows + 1] = row {
            width = "Fill",
            spacing = theme.spacing.xs,
            children = days,
        }
    end
    return rows
end

local day_names = {}
for column, name in ipairs(DAY_NAMES) do
    day_names[column] = cell(util.bold(name), column == 7 and theme.text_contrast(theme.BG) or theme.FG,
        theme.font.xs, { width = DAY_SIDE, align = "Center" })
end

local heading = row { width = "Fill", spacing = theme.spacing.xs, children = day_names }

-- Rebuilt on each clock tick -- at most 42 cells of arithmetic -- although it changes at midnight.
-- ponytail: `:map` must stay pure, so memoizing the day cannot write a cache. Add a date field
-- beside `mantle.system.time` and key on that.
local grid = column {
    width = "Fill",
    spacing = theme.spacing.xs,
    children = mantle.system:map(function(s)
        return week_rows(s and s.time or os.time())
    end),
}

-- Month and year, bold and centred over the grid.
local title = cell(util.bold(mantle.system:map(function(s)
    return os.date("%B %Y", (s and s.time) or os.time())
end)), theme.FG, theme.font.sm, { width = "Fill", align = "Center" })

-- A popup surface's size is explicit, so height follows row count: a five-week month is one
-- `DAY_SIDE` shorter than a six-week one. 1.2 is `renderer::text::shaping::LINE_HEIGHT_RATIO`, which
-- a fixed surface is the one place a config has to know.
local function line_of(font_size)
    return math.ceil(font_size * 1.2)
end

return {
    width = COLUMNS * DAY_SIDE + (COLUMNS - 1) * theme.spacing.xs,
    height = mantle.system:map(function(s)
        local rows = rows_in((s and s.time) or os.time())
        return line_of(theme.font.sm) + line_of(theme.font.xs) + rows * DAY_SIDE + (rows + 1) * theme.spacing.xs
    end),
    node = column {
        width = "Fill",
        spacing = theme.spacing.xs,
        children = { title, heading, grid },
    },
}
