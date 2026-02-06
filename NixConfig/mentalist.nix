{ pkgs, ... }: {
  imports = [
    ./mentalist-hardware.nix
  ];

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