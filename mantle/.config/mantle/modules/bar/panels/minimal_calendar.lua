-- Current month grid with today marked: `os.date`/`os.time` arithmetic with `mantle.system.time`
-- supplying *today*, so it needs no calendar capability and none should be added.
--
-- Not a panel. It sits in the clock's hover tooltip, owned by `modules/bar/indicators/date_time.lua`.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")

local COLUMNS = 7
local DAY_NAMES = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
local DAY_SIDE = theme.calendar_day

-- Today, the month's lead-in blanks, its length and its week count. Lua's normalizing `os.time`
-- makes `day = 0` the previous month's last day, avoiding a month-length table and a leap-year branch.
-- Four to six weeks: fixed six-week sizing would leave a short month's tooltip too tall.
local function month_of(now)
    local today = os.date("*t", now)
    -- `wday` is 1-based from Sunday, matching `DAY_NAMES`.
    local lead = os.date("*t", os.time({ year = today.year, month = today.month, day = 1, hour = 12 })).wday - 1
    local days_in_month = os.date("*t", os.time({ year = today.year, month = today.month + 1, day = 0, hour = 12 })).day
    return today, lead, days_in_month, math.ceil((lead + days_in_month) / COLUMNS)
end

-- `day` is `nil` for a blank, which keeps its column; an absent child would shift the week left.
-- The last column is Saturday, marked like its heading.
local function day_cell(day, is_today, is_saturday)
    return rect {
        width = DAY_SIDE,
        height = DAY_SIDE,
        radius = DAY_SIDE / 2,
        background = is_today and theme.ACCENT or nil,
        children = {
            -- Today is the one date read at a glance, so it carries the weight as well as the disc.
            day and cell({ { text = tostring(day), bold = is_today } },
                is_today and theme.text_contrast(theme.ACCENT)
                or is_saturday and theme.ACCENT
                or theme.FG,
                theme.font.sm, { width = "Fill", align = "Center", align_v = "Center" }) or nil,
        },
    }
end

-- Leading blanks are `nil` days, so the first week uses the same loop as the rest. Trailing blanks
-- exist only inside the last week the month reaches.
local function week_rows(now)
    local today, lead, days_in_month, weeks = month_of(now)
    local rows = {}
    for week = 0, weeks - 1 do
        local days = {}
        for column = 1, COLUMNS do
            local day = week * COLUMNS + column - lead
            local in_month = day >= 1 and day <= days_in_month
            days[column] = day_cell(in_month and day or nil, day == today.day, column == COLUMNS)
        end
        rows[#rows + 1] = row { width = "Fill", spacing = theme.spacing.xs, children = days }
    end
    return rows
end

local day_names = {}
for column, name in ipairs(DAY_NAMES) do
    day_names[column] = cell(util.bold(name), column == COLUMNS and theme.ACCENT or theme.FG,
        theme.font.xs, { width = DAY_SIDE, align = "Center" })
end

-- A popup surface's size is explicit, so height follows row count: a five-week month is one
-- `DAY_SIDE` shorter than a six-week one. 1.2 is `renderer::text::shaping::LINE_HEIGHT_RATIO`, which
-- a fixed surface is the one place a config has to know.
local function line_of(font_size)
    return math.ceil(font_size * 1.2)
end

return {
    width = COLUMNS * DAY_SIDE + (COLUMNS - 1) * theme.spacing.xs,
    height = util.today:map(function(today)
        local rows = select(4, month_of(today))
        return line_of(theme.font.sm) + line_of(theme.font.xs) + rows * DAY_SIDE + (rows + 1) * theme.spacing.xs
    end),
    node = column {
        width = "Fill",
        spacing = theme.spacing.xs,
        children = {
            cell(util.bold(util.today:map(function(today)
                return os.date("%B %Y", today)
            end)), theme.FG, theme.font.sm, { width = "Fill", align = "Center" }),
            row { width = "Fill", spacing = theme.spacing.xs, children = day_names },
            column {
                width = "Fill",
                spacing = theme.spacing.xs,
                children = util.today:map(week_rows),
            },
        },
    },
}
