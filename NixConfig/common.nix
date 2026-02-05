{ pkgs, inputs, ... }: 
let
  # --- Package & Font Categorization ---
  
  fontsList = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.caskaydia-cove
    nerd-fonts.roboto-mono
    scheherazade-new
    noto-fonts
    noto-fonts-color-emoji
    corefonts
    liberation_ttf
    material-icons
    material-symbols
    freefont_ttf
    inter
    source-code-pro
  ];

  coreTools = with pkgs; [
    git curl wget zip _7zz zoxide just inotify-tools 
    bat eza fd ripgrep dysk tokei python3Packages.subliminal
    rsync gemini-cli opencode fnm fzf
  ];

  desktopEnv = with pkgs; [
    kitty starship fastfetch 
    bibata-cursors tela-circle-icon-theme 
    xdg-terminal-exec qt6Packages.qt6ct qt6Packages.qtstyleplugin-kvantum
    brightnessctl cliphist satty
    inputs.quickshell.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  applications = with pkgs; [
    neovim qbittorrent vesktop slack telegram-desktop
    mpv mpvScripts.mpris thunderbird tableplus
    rustdesk anydesk nautilus simple-scan papers 
    gnome-calculator mission-center gnome-disk-utility gnome-firmware
    inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".beta
  ];

  devTools = with pkgs; [
    rustup mold mariadb docker-compose gpu-screen-recorder
  ];

in {
  # ====================================================================
  # SYSTEM CORE
  # ====================================================================

  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  system.stateVersion = "25.11";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    warn-dirty = false;
    substituters = [
      "https://cache.nixos.org"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://nix-mirror.f7l.de"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    # Speed optimizations
    http-connections = 128;
    max-substitution-jobs = 128;
    max-jobs = "auto";
    builders-use-substitutes = true;
  };

  nixpkgs.config.allowUnfree = true;

  # ====================================================================
  # BOOT & HARDWARE
  # ====================================================================

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    blacklistedKernelModules = [ "cdc_acm" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 0;
    };
    plymouth = {
      enable = true;
      theme = "spinner";
    };
    initrd = {
      systemd.enable = true;
      verbose = false;
    };
    consoleLogLevel = 0;
    kernelParams = [ 
      "quiet" "splash" "loglevel=3" "nowatchdog"
    ];
  };

  services.udev.extraRules = ''
    # Samsung/Android/Odin
    SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666"
  '';

  networking = {
    networkmanager.enable = true;
    dhcpcd.enable = false;
  };

  hardware.bluetooth.enable = true;
  hardware.enableRedistributableFirmware = true;

  hardware.graphics.enable = true;
  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  # ====================================================================
  # SERVICES & MULTIMEDIA
  # ====================================================================

  security.rtkit.enable = true;
  services.dbus.implementation = "broker";
  services.gnome.gnome-keyring.enable = true;

  services.displayManager.ly = {
    enable = true;
    settings = {
      animation = "matrix";
      bigclock = "en";
      bigclock_12hr = true;
      allow_empty_password = true;
      save = true;
    };
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  # ====================================================================
  # USER CONFIG & PROGRAMS
  # ====================================================================

  users.users.anas = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    password = "nixos";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.anas = {
      home.stateVersion = "25.11";

      # Mirroring GNU Stow behavior
      home.file = {
        # Individual files from 'config' module
        ".config/starship.toml".source = ../config/.config/starship.toml;
        ".config/xdg-terminals.list".source = ../config/.config/xdg-terminals.list;
        ".config/fastfetchTheme.jsonc".source = ../config/.config/fastfetchTheme.jsonc;
        
        # Directory symlinks
        ".config/kitty".source = ../kitty/.config/kitty;
        ".config/ghostty".source = ../ghostty/.config/ghostty;
        ".config/wezterm".source = ../wezterm/.config/wezterm;
        ".config/foot".source = ../foot/.config/foot;
        ".config/alacritty".source = ../alacritty/.config/alacritty;
        ".config/hypr".source = ../hypr/.config/hypr;
        ".config/niri".source = ../niri/.config/niri;
        ".config/nvim".source = ../nvim/.config/nvim;
        ".config/mpv".source = ../mpv/.config/mpv;
        ".config/fish".source = ../fish/.config/fish;
        ".config/nushell".source = ../nushell/.config/nushell;
        ".config/quickshell".source = ../quickshell/.config/quickshell;
        
        # Wayland/Sway extras
        ".config/waybar".source = ../waybar/.config/waybar;
        ".config/swaync".source = ../swaync/.config/swaync;
        ".config/swaylock".source = ../swaylock/.config/swaylock;
        ".config/swayidle".source = ../swayidle/.config/swayidle;
        ".config/swayosd".source = ../swayosd/.config/swayosd;

        ".local/bin".source = ../bin/.local/bin;
        
        # Files from 'home' module
        ".bashrc".source = ../home/.bashrc;
        ".profile".source = ../home/.profile;
      };
    };
  };

  programs = {
    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
      flake = "/mnt/Work/1Progs/Dots/NixConfig";
    };
    fish.enable = true;
    bash.completion.enable = true;
    kdeconnect.enable = true;
    nano.enable = false;
  };

  documentation = {
    enable = false;
    doc.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

  # ====================================================================
  # ENVIRONMENT & PACKAGES
  # ====================================================================

  fonts.packages = fontsList;

  environment.systemPackages = coreTools ++ desktopEnv ++ applications ++ devTools;
}