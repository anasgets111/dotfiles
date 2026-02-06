{ pkgs, ... }: {
  imports = [
    ./wolverine-hardware.nix
  ];

  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  fileSystems."/mnt/Work" = {
    device = "/dev/disk/by-label/Work";
    fsType = "ext4";
    options = [ "nosuid" "nodev" "nofail" "x-gvfs-show" "x-systemd.makedir" ];
  };

  fileSystems."/mnt/Media" = {
    device = "/dev/disk/by-label/Media";
    fsType = "ext4";
    options = [ "nosuid" "nodev" "nofail" "x-gvfs-show" "x-systemd.makedir" ];
  };

  fileSystems."/mnt/Games" = {
    device = "/dev/disk/by-label/Games";
    fsType = "ext4";
    options = [ "nosuid" "nodev" "nofail" "x-gvfs-show" "x-systemd.makedir" ];
  };

  swapDevices = [ {
    device = "/swapfile";
    size = 8192; # 8GB
  } ];

  # Window Manager & Portals
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Gaming & Performance
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ 
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config.common.default = [ "hyprland" ];
  };

  # Nvidia Configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = pkgs.linuxPackages_latest.nvidiaPackages.latest;
  };

  hardware.graphics = {
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      libva-utils
    ];
  };

  # Packages and Tools
  environment.systemPackages = with pkgs; [
    heroic
    solaar
    mangohud
    hyprpicker
    hyprshot
  ];

  # Solaar rule for Logitech devices
  services.udev.packages = [ pkgs.solaar ];

  networking.hostName = "Wolverine";
}
