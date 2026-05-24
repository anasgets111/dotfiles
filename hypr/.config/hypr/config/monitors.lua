local f = assert(io.open("/proc/sys/kernel/hostname", "r"))
local hostname = f:read("*l"):lower()
f:close()

local host_profiles = {
    wolverine = { output = "DP-1", mode = "3440x1440@165", bitdepth = 10, vrr = 2, icc = "/mnt/Work/1Progs/Windows/Y34wz-30.icm" },
    mentalist = { output = "eDP-1", mode = "1920x1200@60" },
}

hl.monitor(assert(host_profiles[hostname], "unknown host: " .. hostname))

for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        default   = (i == 1) or nil,
        layout    = (i == 2) and "scrolling" or nil,
    })
end
