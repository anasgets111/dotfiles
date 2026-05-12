local function delayed_exec(timeout, cmd, rules)
    hl.timer(function()
        hl.exec_cmd(cmd, rules)
    end, { timeout = timeout, type = "oneshot" })
end

-- Apps
local function run_once()
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("$CARGOBIN/hyprland-per-window-layout")
    hl.exec_cmd("quickshell")
    hl.exec_cmd("systemctl --user enable --now cliphist.service")
    hl.exec_cmd("kdeconnectd")
    hl.exec_cmd("kdeconnect-indicator")
    hl.exec_cmd("speech-dispatcher")

    delayed_exec(2000, "chromium")
    delayed_exec(2000, "zeditor")
    delayed_exec(2000, "qbittorrent")
    delayed_exec(2000, "thunderbird")
    delayed_exec(2000, "Telegram")
    delayed_exec(2000, "vesktop")
    delayed_exec(2000, "slack")
end

hl.on("hyprland.start", run_once)
