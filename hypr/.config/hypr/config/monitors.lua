local function get_system_hostname()
    local file = assert(io.open("/proc/sys/kernel/hostname", "r"))
    local name = (file:read("*l") or ""):lower()
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
    wolverine = {
        monitor = {
            output = "DP-1",
            mode = "3440x1440@165",
            bitdepth = 10,
            vrr = 2,
            icc = "/mnt/Work/1Progs/Windows/Y34wz-30.icm",
        },
    },
    mentalist = {
        monitor = {
            output = "eDP-1",
            mode = "1920x1200@60",
        },
    },
}

local function apply_host_profile(profile)
    if not profile then
        return
    end

    hl.monitor(profile.monitor)
end

apply_host_profile(host_profiles[get_system_hostname()])
apply_workspace_rules()
