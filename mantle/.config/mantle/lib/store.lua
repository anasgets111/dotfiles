-- Restart-persistent config in one file, not two.
--
-- This file owns the path; `persistent_table` has no default. Keep Mantle's hardcoded
-- location so existing `state.json` remains readable. Other configs can choose `$XDG_CACHE_HOME`,
-- beside `shell.lua`, or a separate settings file.
--
-- `config/theme.lua` and this directory hot-reload via `require`. Only runtime user
-- changes need persistence.
local home = os.getenv("HOME") or ""
local state_home = os.getenv("XDG_STATE_HOME")
if not state_home or state_home == "" then
    state_home = home .. "/.local/state"
end

-- `defaults` fills missing keys, creates the file on first run, and does not reset existing shells.
return persistent_table {
    path = state_home .. "/mantle",
    name = "state.json",
    defaults = {
        -- One entry per output, `{ path = ..., fit = ... }`.
        wallpapers = {},
        -- One effect per output. A `.frag` name from
        -- `wallpaper.SHADER_FOLDER`, or `"fade"`, selects the built-in cross-dissolve. Read
        -- validation falls back if the effect file was deleted.
        wallpaper_transition = "fade",
        -- Last successful check, package list, and announced names. The list travels with time: a
        -- restart inside the interval skips its check; without the list, it would say "up to date"
        -- for the rest of the hour.
        -- The forecast is cached whole so a restart inside the hour draws before any request. `weather_location` carries
        -- the `timezone` it was resolved from, which is what lets an hourly cycle tell "same place"
        -- from "this machine has moved". Write it by hand to pin a place and no lookup runs at all.
        weather_code = -1,
        weather_temperature = 0,
        weather_daily = {},
        weather_updated_at = 0,
        weather_location = {},
        -- The rates table keyed by lowercase code, and when it was
        -- fetched. Split into two keys, matching the `updates_*` trio above. A restart inside the
        -- day reuses them and spends no request.
        currency_rates = {},
        currency_updated_at = 0,
        updates_checked_at = 0,
        updates_packages = {},
        updates_notified = "",
        -- Which `config/dev_tools.lua` entries run behind the package manager, keyed by tool name.
        -- Absent means on, so a tool added to that file applies without a state.json edit and only
        -- an explicit `false` here holds one back.
        updates_dev_tools = {},
        -- Two profiles keyed by UPower mains state.
        -- Each has `<stage>_on`/`<stage>_sec` fields; both share `order`. Stage seconds start when
        -- the preceding stage fires, not when the seat goes idle. This preserves "blank after 5
        -- minutes, then lock 10 minutes after that"; absolute times silently shorten the lock gap
        -- when the blank timeout is lowered. Shared `order` is policy, blank before lock or vice
        -- versa, not a cable-change setting. Delays are per profile. Read validation drops unknown
        -- names and appends missing stages rather than silently skipping them. `enabled`
        -- deliberately defaults false. That writes false to a real `state.json` on first run; true
        -- could blank a screen while its owner reads. The modal's one-click master switch says
        -- "automation paused" until enabled.
        -- The four choices the panel offers. One table
        -- keeps the panel's reads and writes grouped by subject.
        screen_recorder = { audio = "desktop", quality = "high", fps = 60, container = "mp4" },
        idle = {
            enabled = false,
            privacy_auto_inhibit = true,
            order = { "dpms", "lock", "suspend" },
            ac = { dpms_on = true, dpms_sec = 300, lock_on = true, lock_sec = 600, suspend_on = false, suspend_sec = 1800 },
            battery = { dpms_on = true, dpms_sec = 120, lock_on = true, lock_sec = 180, suspend_on = true, suspend_sec = 600 },
        },
    },
}
