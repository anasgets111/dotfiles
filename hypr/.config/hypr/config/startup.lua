local startup_commands = {
    "hyprctl setcursor Bibata-Modern-Ice 24",
    "$CARGOBIN/hyprland-per-window-layout",
    "sh -c 'while true; do cat /dev/input/by-id/usb-3537_Controller_00006F64096B22E0-event-joystick >/dev/null 2>&1; sleep 1; done'",
    "quickshell",
    "systemctl --user enable --now cliphist.service",
    "kdeconnectd",
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
