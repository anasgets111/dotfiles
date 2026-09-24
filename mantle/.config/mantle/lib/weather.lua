-- One hourly reading of open-meteo over `curl`, decoded in the exit callback, which is the only one
-- that knows the body is complete. Coordinates come from the timezone's city, not `ipapi.co` (429s
-- on its free tier); write `weather_location` to pin a place instead.
--
-- Retries and the refresh share one deadline, `next_attempt`, compared on `mantle.system`'s 1 Hz
-- push, so no config timer is needed. `launcher/currency.lua` refreshes the same way.
--
-- Nothing is owed until `mantle.storage` has pushed, since the stored stamp says whether a launch
-- owes a request and its `0` default would spend one every time. A level test, not an edge: a reload
-- installs its handler after the capability has already pushed.
local icons = require("config.icons")
local store = require("lib.store")
local util = require("lib.util")

local weather = {}

-- Refresh every hour; retries wait 2s then 4s before giving up until the hour.
local REFRESH_SECONDS = 3600
local RETRY_SECONDS = { 2, 4 }
-- `refresh()` ignores a click inside 30s of the last reading.
local MANUAL_FLOOR_SECONDS = 30

local GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search?count=5&name="

-- WMO codes are sparse, so a lookup, and an unlisted one is "Unknown" rather than a `nil` to test.
local CODES = {
    [0] = { icon = "☀️", desc = "Clear sky" },
    [1] = { icon = "🌤️", desc = "Mainly clear" },
    [2] = { icon = "⛅", desc = "Partly cloudy" },
    [3] = { icon = "☁️", desc = "Overcast" },
    [45] = { icon = "🌫️", desc = "Fog" },
    [48] = { icon = "🌫️", desc = "Depositing rime fog" },
    [51] = { icon = "🌦️", desc = "Drizzle: Light" },
    [53] = { icon = "🌦️", desc = "Drizzle: Moderate" },
    [55] = { icon = "🌧️", desc = "Drizzle: Dense" },
    [56] = { icon = "🌧️❄️", desc = "Freezing Drizzle: Light" },
    [57] = { icon = "🌧️❄️", desc = "Freezing Drizzle: Dense" },
    [61] = { icon = "🌦️", desc = "Rain: Slight" },
    [63] = { icon = "🌧️", desc = "Rain: Moderate" },
    [65] = { icon = "🌧️", desc = "Rain: Heavy" },
    [66] = { icon = "🌧️❄️", desc = "Freezing Rain: Light" },
    [67] = { icon = "🌧️❄️", desc = "Freezing Rain: Heavy" },
    [71] = { icon = "🌨️", desc = "Snow fall: Slight" },
    [73] = { icon = "🌨️", desc = "Snow fall: Moderate" },
    [75] = { icon = "❄️", desc = "Snow fall: Heavy" },
    [77] = { icon = "❄️", desc = "Snow grains" },
    [80] = { icon = "🌦️", desc = "Rain showers: Slight" },
    [81] = { icon = "🌧️", desc = "Rain showers: Moderate" },
    [82] = { icon = "⛈️", desc = "Rain showers: Violent" },
    [85] = { icon = "🌨️", desc = "Snow showers: Slight" },
    [86] = { icon = "❄️", desc = "Snow showers: Heavy" },
    [95] = { icon = "⛈️", desc = "Thunderstorm: Slight or moderate" },
    [96] = { icon = "⛈️🧊", desc = "Thunderstorm with slight hail" },
    [99] = { icon = "⛈️🧊", desc = "Thunderstorm with heavy hail" },
}

---@param code integer|nil
---@return { icon: string, desc: string }
function weather.info(code)
    return CODES[code or -1] or { icon = "❓", desc = "Unknown" }
end

-- The lock screen has one line, so the same codes collapse into six glyphs.
local GLYPH_BUCKETS = {
    [icons.weather_sunny] = { 0, 1 },
    [icons.weather_fog] = { 45, 48 },
    [icons.weather_rain] = { 51, 53, 55, 61, 63, 65, 80, 81, 82 },
    [icons.weather_snow] = { 56, 57, 66, 67, 71, 73, 75, 77, 85, 86 },
    [icons.weather_storm] = { 95, 96, 99 },
}

local GLYPHS = {}
for glyph, codes in pairs(GLYPH_BUCKETS) do
    for _, code in ipairs(codes) do
        GLYPHS[code] = glyph
    end
end

function weather.glyph(code)
    return GLYPHS[code or -1] or icons.weather_cloud
end

-- Off `lib/store.lua`, so a restart inside the hour draws before any request. Store keys read `nil`
-- until storage's first push, so each carries its default.
local function cached(signal, default)
    return signal:map(function(v) return v or default end)
end
weather.code = cached(store.weather_code, -1)
weather.temperature = cached(store.weather_temperature, 0)
weather.daily = cached(store.weather_daily, {})
weather.updated_at = cached(store.weather_updated_at, 0)
weather.location = cached(store.weather_location, {})

-- Not cached: a stale failure would read back as "Weather Unavailable" over a forecast on screen.
weather.failed = state("weather_failed", false)

-- `state`, not locals: a save keeps the backoff. A reload kills a live fetch, and its `exit_cb(nil)`
-- clears `in_flight` before the new evaluation runs. `0` means nothing is scheduled yet.
local in_flight = state("weather_fetching", false)
weather.fetching = in_flight
local retries = state("weather_retries", 0)
local next_attempt = state("weather_next_attempt", 0)

-- Monotonic, not wall: setting the clock must not park the next attempt an hour out. The stored
-- freshness deadline below is wall, and the two are never compared.
local function schedule(seconds)
    next_attempt:set(((mantle.system:get() or {}).monotonic or 0) + seconds)
end

local function failed()
    weather.failed:set(true)
    local attempt = retries:get() + 1
    local backoff = RETRY_SECONDS[attempt]
    -- Out of short retries: wait for the hour, and reset so that hour's cycle gets its own two.
    retries:set(backoff and attempt or 0)
    schedule(backoff or REFRESH_SECONDS)
end

local function http_get(url, apply)
    in_flight:set(true)
    local body = {}
    process.run("curl", { "-fsS", "--max-time", "5", url }, function(line, stream)
        if stream == "stdout" then
            body[#body + 1] = line
        end
    end, function(code)
        in_flight:set(false)
        local data = code == 0 and json.decode(table.concat(body)) or nil
        -- `apply` raising retries like a dead socket.
        if type(data) ~= "table" or not pcall(apply, data) then
            log.warn(("weather: fetch failed (curl exited %s), retrying"):format(tostring(code)))
            failed()
        end
    end)
end

local function fetch_weather(latitude, longitude)
    http_get(string.format(
        "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current_weather=true"
        .. "&timezone=auto&forecast_days=10&past_days=1"
        .. "&daily=temperature_2m_max,temperature_2m_min,weathercode",
        latitude, longitude), function(data)
        local current = data.current_weather
        assert(type(current) == "table", "no current_weather")
        store:set("weather_code", math.floor(current.weathercode or -1))
        store:set("weather_temperature", math.floor((current.temperature or 0) + 0.5))
        store:set("weather_daily", data.daily)
        store:set("weather_updated_at", os.time())
        weather.failed:set(false)
        retries:set(0)
        log.debug("weather:", current.temperature, "C, code", current.weathercode)
        schedule(REFRESH_SECONDS)
    end)
end

-- The zone's last segment is its city.
local function fetch_location(zone)
    local city = zone:match("([^/]+)$"):gsub("_", "%%20")
    http_get(GEOCODING_URL .. city, function(data)
        for _, place in ipairs(data.results or {}) do
            -- Load-bearing: unmatched, `Europe/Kiev` returns a Kiev in the Urals.
            if place.timezone == zone then
                store:set("weather_location", {
                    latitude = place.latitude,
                    longitude = place.longitude,
                    place_name = place.country and (place.name .. ", " .. place.country) or place.name,
                    timezone = zone,
                })
                fetch_weather(place.latitude, place.longitude)
                return
            end
        end
        error("no place in " .. zone)
    end)
end

-- Re-read each cycle so a machine that travels re-resolves; geocode only when the zone changed.
local function fetch()
    in_flight:set(true)
    local zone = ""
    process.run("timedatectl", { "show", "-p", "Timezone", "--value" }, function(line, stream)
        if stream == "stdout" then
            zone = util.trim(line)
        end
    end, function(code)
        if code ~= 0 or zone == "" then
            in_flight:set(false)
            failed()
            return
        end
        local known = store.weather_location:get()
        if known and known.timezone == zone and known.latitude and known.longitude then
            fetch_weather(known.latitude, known.longitude)
        else
            fetch_location(zone)
        end
    end)
end

---`refresh()`: the widget's button. A reading younger than 30s is left alone.
function weather.refresh()
    if in_flight:get() or os.time() - (store.weather_updated_at:get() or 0) < MANUAL_FLOOR_SECONDS then
        return
    end
    retries:set(0)
    fetch()
end

mantle.system:on_change(function(system)
    if not system or in_flight:get() or mantle.storage:get() == nil then
        return
    end
    local due = next_attempt:get()
    -- Nothing scheduled: the deadline is the stored reading's own hour, in wall time.
    local waiting = due == 0 and system.time < (store.weather_updated_at:get() or 0) + REFRESH_SECONDS
        or due ~= 0 and system.monotonic < due
    if not waiting then
        fetch()
    end
end)

local TIME_STEPS = { { 86400, "%dd ago" }, { 3600, "%dh ago" }, { 60, "%dm ago" } }

function weather.time_ago(at, now)
    if not at or at == 0 or not now then
        return ""
    end
    local seconds = math.max(0, now - at)
    for _, step in ipairs(TIME_STEPS) do
        if seconds >= step[1] then
            return string.format(step[2], seconds // step[1])
        end
    end
    return "just now"
end

---The weekday an ISO `YYYY-MM-DD` from `daily.time` names.
---@param iso string|nil
---@return string
function weather.weekday(iso)
    local year, month, day = tostring(iso or ""):match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if not year then
        return ""
    end
    -- Noon, so a timezone shift cannot move the date across midnight and name the wrong weekday.
    local named = os.date("%a",
        os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 12 }))
    ---@cast named string
    return named
end

return weather
