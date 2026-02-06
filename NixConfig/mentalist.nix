{ pkgs, ... }: {
  imports = [
    ./mentalist-hardware.nix
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    options = [ "rw" "relatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [ "rw" "relatime" "fmask=0077" "dmask=0077" "codepage=437" "iocharset=ascii" "shortname=mixed" "utf8" "errors=remount-ro" ];
  };

  fileSystems."/mnt/Work" = {
    device = "/dev/disk/by-label/Work";
    fsType = "ext4";
    options = [ "rw" "relatime" "nosuid" "nodev" "nofail" "x-gvfs-show" "x-systemd.makedir" ];
  };

  # Window Manager & Portals
  programs.niri.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ 
      pkgs.xdg-desktop-portal-gtk 
      pkgs.xdg-desktop-portal-gnome 
    ];
    config.common.default = [ "gnome" ];
  };

  # Power Management
  services.power-profiles-daemon.enable = true;

  # Intel Graphics Configuration
  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt # Supersedes Media SDK for newer GPUs
    intel-vaapi-driver
    libvdpau-va-gl
  ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD"; # Force intel-media-driver
  };

  networking.hostName = "Mentalist";
}
