local hostname = assert(io.popen("uname -n")):read("*l")

local host_profiles = {
    Wolverine = { output = "desc:Lenovo Group Limited Y34wz-30", mode = "3440x1440@165", bitdepth = 10, vrr = 3, icc = "/mnt/Work/1Progs/Windows/Y34wz-30.icm" },
    Mentalist = { output = "eDP-1", mode = "1920x1200@60" },
}

local profile = assert(host_profiles[hostname], "unknown host: " .. hostname)
hl.monitor(profile)

-- ICC prevents fullscreen HDR, so temporarily use an equivalent unprofiled rule.
if profile.icc then
    local suppressed = false
    local unprofiled = {}
    for key, value in pairs(profile) do unprofiled[key] = value end
    unprofiled.icc = nil

    -- Lua exposes the content type, not HDR metadata; do not disrupt ordinary fullscreen apps.
    local function fullscreen_game(workspace)
        local window = workspace and workspace.fullscreen_window
        return window ~= nil and (workspace.fullscreen_mode & 2) ~= 0 and window.content_type == "game"
    end

    local function sync_icc()
        local target = hl.get_monitor(profile.output)
        if target == nil then return end
        local suppress = fullscreen_game(target.active_workspace) or fullscreen_game(target.active_special_workspace)
        if suppress == suppressed then return end
        suppressed = suppress
        if not suppress then return hl.exec_cmd("hyprctl reload") end
        -- A desc:-keyed rule would inherit the profiled rule's ICC.
        unprofiled.output = target.name
        hl.monitor(unprofiled)
    end

    for _, event in ipairs({ "window.fullscreen", "window.destroy", "window.move_to_workspace", "workspace.active", "workspace.special_active" }) do
        hl.on(event, sync_icc)
    end
    sync_icc()
end

for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        default   = (i == 1) or nil,
        layout    = (i == 2) and "scrolling" or nil,
    })
end
