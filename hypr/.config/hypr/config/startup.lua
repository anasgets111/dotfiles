local startup = {
    { "hyprctl setcursor Bibata-Modern-Ice 24" },
    { "$CARGOBIN/hyprland-per-window-layout" },
    { "quickshell" },
    { "systemctl --user enable --now cliphist.service" },
    { "kdeconnectd" },
    { "kdeconnect-indicator" },
    { "speech-dispatcher" },
    { "chromium",                                      2000 },
    { "zeditor",                                       2000 },
    { "qbittorrent",                                   2000 },
    { "thunderbird",                                   2000 },
    { "Telegram",                                      2000 },
    { "vesktop",                                       2000 },
    { "slack",                                         2000 },
}

local function start(command, delay)
    hl.timer(function()
        hl.exec_cmd(command)
    end, { timeout = delay or 0, type = "oneshot" })
end

hl.on("hyprland.start", function()
    for _, entry in ipairs(startup) do
        start(entry[1], entry[2])
    end
end)
