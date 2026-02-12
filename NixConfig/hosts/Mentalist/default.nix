{ pkgs, lib, ... }: {
  imports = [
    ./hardware-config.nix
  ];

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
    options = [ "nosuid" "nodev" "nofail" "x-gvfs-show" "x-systemd.makedir" ];
  };

  # Window Manager & Portals
  programs.niri.enable = true;
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = lib.mkForce [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      common.default = [ "gnome" "gtk" ];
    };
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

  networking.hostName = "Mentalist";
}
