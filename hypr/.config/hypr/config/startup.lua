local startup_commands = {
    "hyprctl setcursor Bibata-Modern-Ice 24",
    "uwsm app -- $CARGOBIN/hyprland-per-window-layout",
    "sh -c 'while true; do cat /dev/input/by-id/usb-3537_Controller_00006F64096B22E0-event-joystick >/dev/null 2>&1; sleep 1; done'",
    "uwsm app -- quickshell",
    "uwsm app -- wl-clip-persist --clipboard regular",
    "uwsm app -- kdeconnectd",
    "uwsm app -- chromium",
    "uwsm app -- zeditor",
    "uwsm app -- qbittorrent",
    "uwsm app -- thunderbird",
    "uwsm app -- Telegram",
    "uwsm app -- vesktop",
    "uwsm app -- slack",
    "uwsm app -- yerdd",
}

hl.on("hyprland.start", function()
    for _, command in ipairs(startup_commands) do
        hl.exec_cmd(command)
    end
end)
