local hostname = assert(io.open("/etc/hostname")):read("*l")

local host_profiles = {
    Wolverine = { output = "desc:Lenovo Group Limited Y34wz-30", mode = "3440x1440@165", bitdepth = 10, vrr = 3, icc = "/mnt/Work/1Progs/Windows/Y34wz-30.icm" },
    Mentalist = { output = "eDP-1", mode = "1920x1200@60" },
}

-- An unknown host gets Hyprland's default: preferred mode, auto position.
local profile = host_profiles[hostname] or {}
if profile.output then hl.monitor(profile) end

-- ICC prevents fullscreen HDR, so temporarily use an equivalent unprofiled rule.
if profile.icc then
    local suppressed = false
    local unprofiled = {}
    for key, value in pairs(profile) do unprofiled[key] = value end
    unprofiled.icc = nil

    -- Lua exposes the content type, not HDR metadata. Only Wayland surfaces can be HDR, and those
    -- that can tag themselves `game` or `video` (mpv); XWayland games stay `none` and keep the ICC.
    local hdr_capable = { game = true, video = true }
    local function fullscreen_hdr(workspace)
        local window = workspace and workspace.fullscreen_window
        return window ~= nil and (workspace.fullscreen_mode & 2) ~= 0 and hdr_capable[window.content_type] == true
    end

    -- Leaving auto HDR rebuilds the monitor's colour description without the ICC a frame after the
    -- fullscreen ends. So drop the ICC at once, but restore only from a recheck a second later. A rule
    -- change applies on the next rendered frame, which a still desktop never draws; a reload applies it
    -- at once and re-adds the ICC rule above.
    -- ponytail: a fixed delay; Lua cannot see when auto HDR has switched back.
    local function sync_icc(may_restore)
        local target = hl.get_monitor(profile.output)
        if target == nil then return end
        -- An open special workspace covers the regular one, and auto HDR follows what shows.
        local suppress = fullscreen_hdr(target.active_special_workspace or target.active_workspace)
        if suppress == suppressed or not (suppress or may_restore) then return end
        suppressed = suppress
        if not suppress then return hl.dispatch(hl.dsp.reload_config()) end
        -- A desc:-keyed rule would inherit the profiled rule's ICC.
        unprofiled.output = target.name
        hl.monitor(unprofiled)
    end

    local function recheck() sync_icc(true) end
    for _, event in ipairs({ "window.fullscreen", "window.destroy", "window.move_to_workspace", "workspace.active", "workspace.special_active" }) do
        hl.on(event, function()
            sync_icc(false)
            hl.timer(recheck, { timeout = 1000, type = "oneshot" })
        end)
    end
    sync_icc(true)
end

-- Special workspaces inset 7.5% per edge, the old `special_scale_factor = 0.85` (a no-op since Hyprland 0.57).
local width, height = (profile.mode or ""):match("^(%d+)x(%d+)")
if width then
    local x, y = math.floor(width * 0.075), math.floor(height * 0.075)
    hl.workspace_rule({ workspace = "s[true]", gaps_out = { top = y, right = x, bottom = y, left = x } })
end

hl.workspace_rule({ workspace = "1", default = true })
hl.workspace_rule({ workspace = "2", layout = "scrolling" })
