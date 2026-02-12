{ config, inputs, ... }: 
let
  dotsPath = "/mnt/Work/1Progs/Dots";
  backupPath = "/mnt/Work/Home_backup";
in {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = { inherit inputs; };
    users.anas = { config, pkgs, lib, osConfig, ... }:
    let
      userTools = with pkgs; [
        zip _7zz zoxide just inotify-tools
        bat eza fd ripgrep dysk tokei python3Packages.subliminal
        fnm fzf btop jq wl-clipboard
        unzip unrar tealdeer git-lfs android-tools
      ];
      devTools = with pkgs; [
        neovim rustup mold docker-compose gpu-screen-recorder
        cargo-binstall cargo-bloat cargo-edit hyprland-per-window-layout
      ];
    in {
      home.stateVersion = "25.11";
      wayland.windowManager.hyprland.systemd.enable = false;
      home.sessionVariables = {
        QT_PLUGIN_PATH = "/run/current-system/sw/lib/qt-6/plugins";
        QML_IMPORT_PATH = "/run/current-system/sw/lib/qt-6/qml";
        QML2_IMPORT_PATH = "/run/current-system/sw/lib/qt-6/qml";
      } // lib.optionalAttrs (osConfig.networking.hostName == "Mentalist") {
        LIBVA_DRIVER_NAME = "iHD";
      };
      home.packages = userTools ++ devTools ++ (with pkgs; [
        qbittorrent
        vesktop
        slack
        telegram-desktop
        mpv
        mpvScripts.mpris
        thunderbird
        tableplus
        rustdesk-flutter
        nautilus
        nautilus-python
        simple-scan
        papers
        gnome-calculator
        mission-center
        gnome-disk-utility
        gnome-firmware
        zed-editor
        inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".beta
      ]);

      xdg.userDirs = {
        enable = true;
        download = "/mnt/Work/Downloads";
      };

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
        };
      };

      programs.vscode = {
        enable = true;
        package = pkgs.vscode.fhs;
      };

      home.file = let
        # 1. Stow-like Modules (instant edits from your Dots folder)
        stowModules = {
          ".config/kitty".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/kitty/.config/kitty";
          ".config/ghostty".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/ghostty/.config/ghostty";
          ".config/wezterm".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/wezterm/.config/wezterm";
          ".config/foot".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/foot/.config/foot";
          ".config/alacritty".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/alacritty/.config/alacritty";
          ".config/hypr".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/hypr/.config/hypr";
          ".config/niri".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/niri/.config/niri";
          ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/nvim/.config/nvim";
          ".config/mpv".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/mpv/.config/mpv";
          ".config/fish".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/fish/.config/fish";
          ".config/nushell".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/nushell/.config/nushell";
          ".config/quickshell".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/quickshell/.config/quickshell";
          
          # Wayland/Sway extras
          ".config/waybar".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/waybar/.config/waybar";
          ".config/swaync".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/swaync/.config/swaync";
          ".config/swaylock".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/swaylock/.config/swaylock";
          ".config/swayidle".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/swayidle/.config/swayidle";
          ".config/swayosd".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/swayosd/.config/swayosd";

          # Binaries and individual config files
          ".local/bin".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/bin/.local/bin";
          ".config/starship.toml".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/config/.config/starship.toml";
          ".config/xdg-terminals.list".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/config/.config/xdg-terminals.list";
          ".config/fastfetchTheme.jsonc".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/config/.config/fastfetchTheme.jsonc";

          # Home files
          ".bashrc".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/home/.bashrc";
          ".profile".source = config.lib.file.mkOutOfStoreSymlink "${dotsPath}/home/.profile";
        };

        # 2. Shared/Persistent Data (folders that Apps write to)
        sharedData = {
          ".ssh".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.ssh";
          ".local/share/gnupg".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.local/share/gnupg";
          ".thunderbird".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.thunderbird";
          ".zen".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.zen";
          ".vscode".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.vscode";
          ".config/Code".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/Code";
          ".config/Slack".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/Slack";
          ".config/vesktop".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/vesktop";
          ".local/share/TelegramDesktop".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.local/share/TelegramDesktop";
          ".config/qBittorrent".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/qBittorrent";
          ".config/zed".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/zed";
          ".local/share/zed".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.local/share/zed";
          ".config/github-copilot".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/github-copilot";
          ".gemini".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.gemini";
          ".themes".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.themes";
          ".config/gtk-2.0".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/gtk-2.0";
          ".config/gtk-3.0".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/gtk-3.0";
          ".config/gtk-4.0".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/gtk-4.0";
          ".config/Kvantum".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/Kvantum";
          ".config/qt5ct".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/qt5ct";
          ".config/qt6ct".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/qt6ct";
          ".config/composer".source = config.lib.file.mkOutOfStoreSymlink "${backupPath}/.config/composer";
        };
        # Disabled intentionally while stabilizing HM startup.
        # bootstrapScript = {
        #   ".config/hm/bootstrap-user-tools.sh" = {
        #     executable = true;
        #     text = ''
        #       #!/usr/bin/env bash
        #       set -euo pipefail
        #
        #       if [ ! -f "$HOME/.local/share/mkcert/rootCA.pem" ]; then
        #         ${pkgs.mkcert}/bin/mkcert -install || true
        #       fi
        #
        #       if [ ! -d "$HOME/.local/share/fnm" ]; then
        #         ${pkgs.fnm}/bin/fnm install --lts
        #         ${pkgs.fnm}/bin/fnm default lts
        #       fi
        #
        #       ${pkgs.fnm}/bin/fnm exec --lts npm install -g @google/gemini-cli opencode-ai @openai/codex
        #     '';
        #   };
        # };
      in stowModules // sharedData;
    };
  };
}
