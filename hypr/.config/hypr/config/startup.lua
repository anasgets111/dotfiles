local startup_commands = {
    "hyprctl setcursor Bibata-Modern-Ice 24",
    "$CARGOBIN/hyprland-per-window-layout",
    "quickshell",
    "systemctl --user enable --now cliphist.service",
    "kdeconnectd",
    "kdeconnect-indicator",
    "speech-dispatcher",
    "chromium",
    "zeditor",
    "qbittorrent",
    "thunderbird",
    "Telegram",
    "vesktop",
    "slack",
}

hl.on("hyprland.start", function()
    for _, command in ipairs(startup_commands) do
        hl.exec_cmd(command)
    end
end)
