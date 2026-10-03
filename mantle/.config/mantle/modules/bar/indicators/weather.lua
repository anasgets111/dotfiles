-- Three preview cards expand to show yesterday plus the ten-day forecast. Like `indicators/system_info.lua` this lives under
-- `indicators/` but never reaches the bar: `panels/notification_history.lua` is the only caller.
--
-- One map builds the forecast cards; expansion changes their labels and clipped height.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local weather = require("lib.weather")
local disclosure = require("lib.disclosure")
local cell = require("components.cell")
local panel_row = require("components.panel_row")
local panel_action_icon = require("components.panel_action_icon")
local panel_card = require("components.panel_card")

local COLUMNS = 4
-- `past_days=1` puts yesterday first, so today is the second entry rather than the first.
local YESTERDAY, TODAY, TOMORROW = 1, 2, 3

-- Half-up rounding, not `%.0f`'s half-to-even.
local function degrees(value)
    return string.format("%d°", math.floor((value or 0) + 0.5))
end

local function has_data(daily)
    return type(daily) == "table" and type(daily.time) == "table" and #daily.time > 0
end

local CENTRED = { width = "fill", align = "center" }

---@param daily table
---@param index integer
---@param opts { label?: string, expanded?: Signal<boolean>, today?: boolean, height?: integer }
local function day_card(daily, index, opts)
    local code = math.floor((daily.weathercode or {})[index] or -1)
    local weekday = weather.weekday((daily.time or {})[index])
    local heading = opts.expanded and util.choose(opts.expanded, weekday, opts.label) or opts.label or weekday
    return panel_card({
        cell(util.bold(heading), opts.today and theme.FG or theme.DIM, theme.font.sm, CENTRED),
        cell(weather.info(code).icon, theme.FG, theme.font.xl, CENTRED),
        cell(util.bold(degrees((daily.temperature_2m_max or {})[index])), theme.FG, theme.font.lg, CENTRED),
        cell(degrees((daily.temperature_2m_min or {})[index]), theme.DIM, theme.font.sm, CENTRED),
    }, {
        width = "fill",
        height = opts.height,
        tone = opts.today and "active" or "standard",
        padding = theme.spacing.sm,
    })
end

local id = "notifications"
local expanded = disclosure.state("weather_expanded_" .. id, false)

local body = weather.daily:map(function(daily)
    if not has_data(daily) then
        return {}
    end
    local preview = row {
        width = "fill",
        spacing = theme.spacing.sm,
        children = {
            day_card(daily, YESTERDAY, { label = "Yesterday", expanded = expanded }),
            day_card(daily, TODAY, { label = "Today", expanded = expanded, today = true }),
            day_card(daily, TOMORROW, { label = "Tomorrow", expanded = expanded }),
        },
    }
    -- Keep the three-day preview in place; the remaining eight days form two rows.
    local rows = {}
    local days = #daily.time
    for first = TOMORROW + 1, days, COLUMNS do
        local children = {}
        for index = first, math.min(first + COLUMNS - 1, days) do
            children[#children + 1] = day_card(daily, index,
                { height = theme.item_height * 3 })
        end
        for _ = #children + 1, COLUMNS do
            children[#children + 1] = rect { width = "fill", height = theme.item_height * 3 }
        end
        rows[#rows + 1] = row { width = "fill", spacing = theme.spacing.sm, children = children }
    end
    if #rows == 0 then
        return { preview }
    end
    -- Keep the rows mounted while the clipped height shrinks, including a quick reversal.
    return { preview, rect {
        width = "fill",
        height = util.choose(expanded, #rows * (theme.item_height * 3 + theme.spacing.sm), 0),
        clip = "box",
        animate = { height = { duration = theme.animation_ms, easing = "out_cubic" } },
        children = { column {
            width = "fill",
            padding = { top = theme.spacing.sm },
            spacing = theme.spacing.sm,
            children = rows,
        } },
    } }
end)

local ready = weather.daily:map(has_data)

return column {
    width = "fill",
    spacing = theme.spacing.sm,
    children = {
        -- The section's disclosure row: the reading now and its age, opening the full forecast.
        -- With no forecast the line says why, and the refresh icon is the retry.
        panel_row {
            slot = "weather-toggle-" .. id,
            icon = weather.code:map(weather.glyph),
            title = "Weather",
            subtitle = computed({ ready, weather.failed, weather.temperature, weather.updated_at, mantle.system },
                function(has, bad, now, at, system)
                    if not has then
                        return bad and "Weather unavailable" or "Loading forecast…"
                    end
                    return string.format("%s · Updated %s", degrees(now),
                        weather.time_ago(at, system and system.time))
                end),
            expanded = expanded,
            trailing = panel_action_icon(icons.refresh, weather.refresh, {
                slot = "weather-refresh-" .. id,
                spinning = weather.fetching,
            }),
        },
        column { width = "fill", children = body },
    },
}
