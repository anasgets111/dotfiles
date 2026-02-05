{ pkgs, ... }: {
  boot.kernelModules = [ "kvm-intel" ];
  hardware.cpu.intel.updateMicrocode = true;

  # Intel Graphics Configuration
  services.xserver.videoDrivers = [ "modesetting" ]; # Or "intel" depending on preference, modesetting is usually preferred for modern Intel
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    intel-vaapi-driver
    libvdpau-va-gl
  ];

  # File Systems
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

  networking.hostName = "Mentalist";
}