{ pkgs, lib, ... }:
let
  dataMountOptions = [ "nosuid" "nodev" "nofail" "x-gvfs-show" "x-systemd.makedir" ];
in {
  imports = [
    ./hardware-config.nix
  ];

  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [ "nosuid" "nodev" "noexec" "fmask=0177" "dmask=0077" ];
  };

  fileSystems."/mnt/Work" = {
    device = "/dev/disk/by-label/Work";
    fsType = "ext4";
    options = dataMountOptions;
  };

  fileSystems."/mnt/Media" = {
    device = "/dev/disk/by-label/Media";
    fsType = "ext4";
    options = dataMountOptions;
  };

  fileSystems."/mnt/Games" = {
    device = "/dev/disk/by-label/Games";
    fsType = "ext4";
    options = dataMountOptions;
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
    xdgOpenUsePortal = true;
    extraPortals = lib.mkForce [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [ "hyprland" "gnome" "gtk" ];
      hyprland = {
        "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gnome" ];
      };
    };
  };

  # Nvidia Configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
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
