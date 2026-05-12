local function get_system_hostname()
    local host = os.getenv("hostname") or os.getenv("HOSTNAME")
    return (host or ""):match("^%s*(.-)%s*$"):lower()
end

local function apply_workspace_rules(monitor_id)
    for i = 1, 10 do
        hl.workspace_rule({
            workspace = tostring(i),
            monitor = monitor_id,
            default = (i == 1) or nil,
        })
    end
end

-- Profiles
local host_profiles = {
    wolverine = function()
        local monitor = "DP-1"
        hl.monitor({
            output = monitor,
            mode = "3440x1440@165",
            bitdepth = 10,
            vrr = 2
        })
        apply_workspace_rules(monitor)
        hl.config({ cursor = { default_monitor = monitor } })
    end,

    mentalist = function()
        local monitor = "eDP-1"
        hl.monitor({
            output = monitor,
            mode = "1920x1200@60",
        })
        apply_workspace_rules(monitor)
    end
}

-- Active Profile
local current_host = get_system_hostname()

if host_profiles[current_host] then
    host_profiles[current_host]()
end

return {
    get_system_hostname = get_system_hostname,
    current_host = current_host,
}
