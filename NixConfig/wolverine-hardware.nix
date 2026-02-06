{ config, lib, modulesPath, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" ];
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

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
}
