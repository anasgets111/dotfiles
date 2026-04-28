local M = {}

function M.apply()
  hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("$CARGOBIN/hyprland-per-window-layout")

    hl.exec_cmd("quickshell")
    hl.exec_cmd("systemctl --user enable --now cliphist.service")

    hl.exec_cmd("kdeconnectd")
    hl.exec_cmd("kdeconnect-indicator")
    hl.exec_cmd("speech-dispatcher")

    hl.exec_cmd("[workspace 2 silent] sleep 2 && chromium")
    hl.exec_cmd("[workspace 3 silent] sleep 2 && zeditor")
    hl.exec_cmd("[workspace 5 silent] sleep 2 && qbittorrent")
    hl.exec_cmd("[workspace 7 silent] sleep 2 && thunderbird")
    hl.exec_cmd("[workspace special:telegram silent] sleep 2 && Telegram")
    hl.exec_cmd("[workspace special:vesktop silent] sleep 2 && vesktop")
    hl.exec_cmd("[workspace special:slack silent] sleep 2 && slack")
  end)
end

return M
