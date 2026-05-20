local delayed_timeout = 2000

local immediate_startup = {
    "hyprctl setcursor Bibata-Modern-Ice 24",
    "$CARGOBIN/hyprland-per-window-layout",
    "quickshell",
    "systemctl --user enable --now cliphist.service",
    "kdeconnectd",
    "kdeconnect-indicator",
    "speech-dispatcher",
}

local delayed_startup = {
    "chromium",
    "zeditor",
    "qbittorrent",
    "thunderbird",
    "Telegram",
    "vesktop",
    "slack",
}

local function run_once()
    for _, command in ipairs(immediate_startup) do
        hl.exec_cmd(command)
    end

    for _, command in ipairs(delayed_startup) do
        hl.timer(function()
            hl.exec_cmd(command)
        end, { timeout = delayed_timeout, type = "oneshot" })
    end
end

hl.on("hyprland.start", run_once)
