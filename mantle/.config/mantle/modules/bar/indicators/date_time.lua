-- One control holds the notification state and clock. Date and time share one cell, since two read
-- as two modules, and seconds are omitted: a per-second clock re-resolves for a digit nobody reads.
-- Twelve-hour with AM/PM is fixed, because a config has no locale to ask.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local tooltip = require("components.tooltip")
local calendar = require("modules.bar.panels.minimal_calendar")
local weather = require("lib.weather")

local SLOT = "clock"

-- Bold: it is the bar's one always-on readout, and the weight is what separates it from the
-- indicators either side. The weather reading sits in front of the time once there is one, which
-- `weather.code`'s `-1` default says.
local clock = cell(util.bold(computed({ mantle.system, weather.code, weather.temperature },
    function(s, code, celsius)
        local shown = os.date("%a %d %b  %I:%M %p", s and s.time)
        if (code or -1) >= 0 then
            shown = string.format("%d°C %s %s", celsius or 0, weather.info(code).icon, shown)
        end
        return shown
    end)), theme.text_contrast(theme.GLASS_CONTROL), theme.font.sm, { align_v = "Center" })

-- The only tooltip with an explicit `width`/`height`: its `width = "Fill"` rows and fixed-cell grid
-- leave `components/tooltip.lua` no content-sized extent to measure, and a month is four to six
-- weeks tall.
local DATE_LINE = math.ceil(theme.font.sm * 1.2)
local TIME_LINE = math.ceil(theme.font.xs * 1.2)
-- Two more `sm`/`xs` lines and the two gaps they add, on a tip whose height is declared rather than
-- measured.
local WEATHER_LINES = DATE_LINE + TIME_LINE + theme.spacing.xs * 2

local clock_tooltip = tooltip({
    id = "clock_tooltip",
    slot = SLOT,
    width = calendar.width + theme.spacing.sm * 2,
    -- The date line carries no air of its own, and shared `xs` left it against the border.
    padding_v = theme.spacing.md,
    height = calendar.height:map(function(grid)
        return grid + DATE_LINE + TIME_LINE + WEATHER_LINES + theme.spacing.md * 2 + theme.spacing.xs * 2
    end),
    children = {
        -- Two runs in one cell, not a row: this tip declares its width, and "Thunderstorm: Slight
        -- or moderate in Giza, Egypt" is half again wider than a month grid, so it must elide.
        cell(computed({ weather.code, weather.location }, function(code, where)
            if (code or -1) < 0 then
                return ""
            end
            local place = where and where.place_name or ""
            return {
                { text = weather.info(code).desc },
                { text = place ~= "" and (" in " .. place) or "", color = theme.DIM },
            }
        end), theme.TOOLTIP_FG, theme.font.sm, { width = "Fill", align = "Center" }),
        cell(computed({ weather.updated_at, mantle.system }, function(at, s)
            local ago = weather.time_ago(at, s and s.time)
            return ago ~= "" and ("Last updated " .. ago) or ""
        end), theme.DIM, theme.font.xs, { width = "Fill", align = "Center" }),
        cell(util.label(mantle.system, function(s)
            return os.date("%A %d %B %Y", s.time)
        end), theme.TOOLTIP_FG, theme.font.sm, { width = "Fill", align = "Center" }),
        cell(util.label(mantle.system, function(s)
            return os.date("%I:%M:%S %p", s.time)
        end), theme.DIM, theme.font.xs, { width = "Fill", align = "Center" }),
        calendar.node,
    },
})

return { clock = clock, slot = SLOT, tooltip = clock_tooltip }
