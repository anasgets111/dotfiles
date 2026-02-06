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
    font-awesome
  ];

  coreTools = with pkgs; [
    git curl wget zip _7zz zoxide just inotify-tools 
    bat eza fd ripgrep dysk tokei python3Packages.subliminal
    rsync gemini-cli fnm fzf
    btop jq wl-clipboard unzip unrar tealdeer git-lfs
    pciutils usbutils lshw ffmpegthumbnailer
    android-tools
    codex
    inputs.opencode.packages."${pkgs.stdenv.hostPlatform.system}".default
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
    rustdesk anydesk nautilus nautilus-python simple-scan papers 
    gnome-calculator mission-center gnome-disk-utility gnome-firmware
    inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".beta
    zed-editor
  ];

  devTools = with pkgs; [
    rustup mold docker-compose gpu-screen-recorder
    cargo-binstall cargo-bloat cargo-edit hyprland-per-window-layout
  ];

in {
  # ====================================================================
  # SYSTEM CORE
  # ====================================================================

  imports = [
    ./home.nix
    ./php.nix
    ./containers.nix
  ];

  system.stateVersion = "25.11";

  time.timeZone = "Africa/Cairo";
  i18n.defaultLocale = "en_US.UTF-8";

  services.timesyncd.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    warn-dirty = false;
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
    # Speed optimizations
    http-connections = 5
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
  services.gvfs.enable = true;

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
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # ====================================================================
  # USER CONFIG & PROGRAMS
  # ====================================================================

  users.users.anas = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    password = "nixos";
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
    dconf.enable = true;
    nautilus-open-any-terminal = {
      enable = true;
      terminal = "kitty";
    };
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