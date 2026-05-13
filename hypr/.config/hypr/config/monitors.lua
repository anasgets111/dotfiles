local function get_system_hostname()
    local file = io.open("/proc/sys/kernel/hostname", "r")

    if not file then
        return ""
    end

    local name = (file:read("*l") or ""):match("^%s*(.-)%s*$"):lower()
    file:close()

    return name
end

local function apply_workspace_rules()
    for i = 1, 10 do
        hl.workspace_rule({
            workspace = tostring(i),
            default = (i == 1) or nil,
            layout = (i == 2) and "scrolling" or nil,
        })
    end
end

local host_profiles = {
    wolverine = function()
        local monitor = "DP-1"
        hl.monitor({
            output = monitor,
            mode = "3440x1440@165",
            bitdepth = 10,
            vrr = 2,
            icc = "/mnt/Work/1Progs/Windows/Y34wz-30.icm"
        })
        hl.config({ cursor = { default_monitor = monitor } })
    end,

    mentalist = function()
        hl.monitor({
            output = "eDP-1",
            mode = "1920x1200@60",
        })
    end
}

local current_host = get_system_hostname()
local profile = host_profiles[current_host]

if profile then
    profile()
end

apply_workspace_rules()

return {
    get_system_hostname = get_system_hostname,
    current_host = current_host,
}
