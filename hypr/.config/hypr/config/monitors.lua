local function normalize_hostname(name)
	return (name or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function hostname()
	local env_hostname = os.getenv("HOSTNAME")

	if env_hostname and env_hostname ~= "" then
		return normalize_hostname(env_hostname)
	end

	for _, path in ipairs({
		"/proc/sys/kernel/hostname",
		"/etc/hostname",
	}) do
		local file = io.open(path, "r")

		if file then
			local name = normalize_hostname(file:read("*l"))
			file:close()

			if name ~= "" then
				return name
			end
		end
	end

	return ""
end

local function workspace_rules(main_monitor, workspace_2_layout)
	for workspace = 1, 10 do
		local rule = {
			workspace = tostring(workspace),
			monitor = main_monitor,
		}

		if workspace == 1 then
			rule.default = true
		end

		if workspace == 2 and workspace_2_layout then
			rule.layout = workspace_2_layout
		end

		hl.workspace_rule(rule)
	end
end

local function desktop()
	local main_monitor = "DP-1"

	hl.monitor({
		output = main_monitor,
		mode = "3440x1440@165",
		position = "0x0",
		scale = 1,
		bitdepth = 10,
		vrr = 2,
	})

	workspace_rules(main_monitor, "scrolling")

	hl.config({
		cursor = {
			default_monitor = main_monitor,
		},
	})
end

local function laptop()
	local main_monitor = "eDP-1"

	hl.monitor({
		output = main_monitor,
		mode = "1920x1200@60",
		position = "0x0",
	})

	workspace_rules(main_monitor)
end

local selected_host = hostname()

if selected_host == "wolverine" then
	desktop()
elseif selected_host == "mentalist" then
	laptop()
end

return {
	hostname = hostname,
	selected_host = selected_host,
}
