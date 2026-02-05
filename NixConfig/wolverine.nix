{ pkgs, ... }: {
  boot.kernelModules = [ "kvm-amd" ];
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  hardware.cpu.amd.updateMicrocode = true;

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

  # Packages and Tools
  environment.systemPackages = with pkgs; [
    heroic
    solaar
  ];

  # Solaar rule for Logitech devices
  services.udev.packages = [ pkgs.solaar ];

  # File Systems
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
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

  networking.hostName = "Wolverine";
}
