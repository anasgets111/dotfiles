local hostname = assert(io.popen("uname -n")):read("*l")
local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or ".") .. "/.config")
local saved_path = config_home .. "/Obelisk/monitors.lua"

local host_profiles = {
    Wolverine = { output = "desc:Lenovo Group Limited Y34wz-30", mode = "3440x1440@165", bitdepth = 10, vrr = 2 },
    Mentalist = { output = "eDP-1", mode = "1920x1200@60" },
}

hl.monitor(assert(host_profiles[hostname], "unknown host: " .. hostname))

local saved = loadfile(saved_path)
local saved_monitors = saved and saved() or {}
local profile = saved_monitors[1]

-- ponytail: This host has one ICC display. Use per-output state if that changes.
if profile and profile.icc then
    local suppressed = false
    local unprofiled = {}
    for key, value in pairs(profile) do unprofiled[key] = value end
    unprofiled.icc = nil

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
        unprofiled.output = "desc:" .. target.description
        hl.monitor(unprofiled)
    end

    -- Lua exposes the content type, not HDR metadata; do not disrupt ordinary fullscreen apps.
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
