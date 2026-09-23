-- Three day cards that open into a ten-day grid. Like `indicators/system_info.lua` this lives under
-- `indicators/` but never reaches the bar: `panels/notification_history.lua` is the only caller.
--
-- Thirteen cards read the same four parallel arrays, so the body is one `computed` over the forecast
-- returning nodes. Per-field signals would resolve that table thirteen times a pass. The
-- hidden-subtree freeze makes the rebuild free while the sidebar is shut.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local weather = require("lib.weather")
local cell = require("components.cell")
local icon_button = require("components.icon_button")
local expander_header = require("components.expander_header")
local panel_card = require("components.panel_card")
local action_button = require("components.action_button")
local spinner = require("components.spinner")

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

local CENTRED = { width = "Fill", align = "Center" }

---@param daily table
---@param index integer
---@param opts { label?: string, today?: boolean, height?: integer }
local function day_card(daily, index, opts)
    local code = math.floor((daily.weathercode or {})[index] or -1)
    -- The named days lose their names once the grid is open: "Today" beside "Wed" reads as two
    -- scales at once.
    local heading = opts.label or weather.weekday((daily.time or {})[index])
    return panel_card({
        cell(util.bold(heading), opts.today and theme.FG or theme.DIM, theme.font.sm, CENTRED),
        cell(weather.info(code).icon, theme.FG, theme.font.xl, CENTRED),
        cell(util.bold(degrees((daily.temperature_2m_max or {})[index])), theme.FG, theme.font.lg, CENTRED),
        cell(degrees((daily.temperature_2m_min or {})[index]), theme.DIM, theme.font.sm, CENTRED),
    }, {
        width = "Fill",
        height = opts.height,
        tone = opts.today and "active" or "standard",
        padding = theme.spacing.sm,
    })
end

---@param id string Names this instance's `expanded` state and its hover slots.
return function(id)
    local expanded = state("weather_expanded_" .. id, false)

    local body = computed({ weather.daily, expanded }, function(daily, open)
        if not has_data(daily) then
            return {}
        end
        local rows = { row {
            width = "Fill",
            spacing = theme.spacing.sm,
            children = {
                day_card(daily, YESTERDAY, { label = not open and "Yesterday" or nil }),
                day_card(daily, TODAY, { label = not open and "Today" or nil, today = true }),
                day_card(daily, TOMORROW, { label = not open and "Tomorrow" or nil }),
            },
        } }
        if not open then
            return rows
        end
        -- Four to a row, the last row short rather than stretched: a lone Thursday card three
        -- columns wide is not a grid.
        local days = #daily.time
        for first = TOMORROW + 1, days, COLUMNS do
            local children = {}
            for index = first, math.min(first + COLUMNS - 1, days) do
                children[#children + 1] = day_card(daily, index, { height = theme.item_height * 3 })
            end
            for _ = #children + 1, COLUMNS do
                children[#children + 1] = rect { width = "Fill", height = theme.item_height * 3 }
            end
            rows[#rows + 1] = row { width = "Fill", spacing = theme.spacing.sm, children = children }
        end
        return rows
    end)

    local ready = weather.daily:map(has_data)
    local blank = ready:map(function(yes) return not yes end)
    -- The label toggles the grid; the middle carries the age of the reading, accented while open so
    -- it reads as part of the header.
    local toggle = expander_header(expanded, "weather-toggle-" .. id, expanded:map(function(open)
        return open and "Show Less" or "10 Day Forecast"
    end), cell(computed({ weather.updated_at, mantle.system }, function(at, system)
        return "Updated " .. weather.time_ago(at, system and system.time)
    end), expanded:map(function(open)
        return open and theme.with_opacity(theme.ACCENT, 0.75) or theme.DIM
    end), theme.font.xs, { width = "Fill", align = "End", align_v = "Center" }), { visible = ready })

    return column {
        width = "Fill",
        spacing = theme.spacing.sm,
        children = {
            row {
                width = "Fill",
                spacing = theme.spacing.sm,
                align_v = "Center",
                children = {
                    toggle,
                    -- Holds the right edge while the toggle is hidden.
                    rect { width = "Fill", visible = blank },
                    icon_button(icons.refresh, weather.refresh, {
                        slot = "weather-refresh-" .. id,
                        size = theme.item_height,
                        icon_size = theme.icon.sm,
                        spinning = weather.fetching,
                    }),
                },
            },
            column { width = "Fill", spacing = theme.spacing.sm, children = body },
            panel_card({
                column {
                    width = "Fill",
                    spacing = theme.spacing.sm,
                    align_h = "Center",
                    children = {
                        row {
                            align_h = "Center",
                            align_v = "Center",
                            spacing = theme.spacing.sm,
                            children = {
                                spinner(weather.fetching, theme.control.xs),
                                cell(weather.failed:map(function(bad)
                                    return bad and "Weather Unavailable" or "Loading Forecast…"
                                end), theme.DIM, theme.font.sm, { align = "Center", align_v = "Center" }),
                            },
                        },
                        action_button("Retry", weather.refresh, "weather-retry-" .. id, {
                            tone = "quiet",
                            visible = weather.failed,
                        }),
                    },
                },
            }, {
                width = "Fill",
                visible = blank,
                outlined = true,
                padding = theme.spacing.md,
            }),
        },
    }
end
