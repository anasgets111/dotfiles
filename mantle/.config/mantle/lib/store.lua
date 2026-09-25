-- Restart-persistent config in one file. Mantle's hardcoded location keeps existing `state.json`
-- readable. Only runtime user changes live here; `config/` hot-reloads through `require`.
local state_home = os.getenv("XDG_STATE_HOME")
if not state_home or state_home == "" then
    state_home = (os.getenv("HOME") or "") .. "/.local/state"
end

-- `defaults` fills missing keys and creates the file on first run; existing values are kept.
return persistent_table {
    path = state_home .. "/mantle",
    name = "state.json",
    defaults = {
        -- One entry per output, `{ path = ..., fit = ... }`.
        wallpapers = {},
        -- A `.frag` name from `wallpaper.SHADER_FOLDER`, or `"fade"` for the built-in cross-dissolve.
        wallpaper_transition = "fade",
        -- Cached whole so a restart inside the hour draws before any request. `weather_location`
        -- carries the `timezone` it was resolved from, telling "same place" from "moved"; write it by
        -- hand to pin a place and skip lookups.
        weather_code = -1,
        weather_temperature = 0,
        weather_daily = {},
        weather_updated_at = 0,
        weather_location = {},
        -- Rates keyed by lowercase code; a restart inside the day reuses them.
        currency_rates = {},
        currency_updated_at = 0,
        -- Launcher launches by desktop id, `{ count = n, last = os.time() }`.
        app_usage = {},
        -- The list travels with the check time: a restart inside the interval skips its check, and
        -- without the list it would say "up to date" for the rest of the hour.
        updates_checked_at = 0,
        updates_packages = {},
        updates_notified = "",
        -- Keyed by `config/dev_tools.lua` name. Absent means on; only an explicit `false` holds one back.
        updates_dev_tools = {},
        updates_aur = true,
        screen_recorder = { audio = "desktop", quality = "high", fps = 60, container = "mp4" },
        -- Popups and sounds pause while an app captures the screen, so a chat never lands in a stream.
        notifications_dnd_while_sharing = true,
        -- Two profiles keyed by mains state, sharing `order`. `lib/idle.lua` holds every default.
        idle = {},
    },
}
