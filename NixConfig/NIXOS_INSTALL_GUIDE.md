# NixOS Installation Guide (Wolverine)

Follow these steps exactly to install NixOS using your existing Flake configuration.

## 1. Boot the NixOS Live ISO
Boot from your Ventoy USB and select the NixOS ISO. Once the terminal is ready:

## 2. Format the Target Partitions
We will format the existing Boot and Archlinux partitions. **Double-check your device names with `lsblk` before running these.**

```bash
# Format the Boot partition
sudo mkfs.vfat -F 32 -n BOOT /dev/nvme0n1p1

# Format the Root partition (setting label to 'nixos' to match config)
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
```

## 3. Mount the Filesystem Hierarchy
Mount everything into `/mnt` so the installer can see the target structure.

```bash
# 1. Mount Root
sudo mount /dev/disk/by-label/nixos /mnt

# 2. Mount Boot
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/BOOT /mnt/boot

# 3. Mount Work (Where your Dots and Flake live)
sudo mkdir -p /mnt/mnt/Work
sudo mount /dev/disk/by-label/Work /mnt/mnt/Work
```

## 4. Generate Hardware Configuration
Since hardware differs between machines, we need to generate a specific config for this machine.

### Method A: From the Live ISO (Recommended)
After mounting your drives in Step 3, run:
```bash
# Generate the config based on mounted drives
sudo nixos-generate-config --root /mnt --show-config > /mnt/mnt/Work/1Progs/Dots/NixConfig/wolverine-hardware.nix
```

### Method B: From Arch Linux (Before Installation)
If you have `nix` installed on Arch, you can scan your hardware directly:
```bash
nix shell nixpkgs#nixos-install-tools -c nixos-generate-config --show-hardware-config --no-filesystems
```
Copy the output into your `wolverine-hardware.nix` or `mentalist-hardware.nix`. Note that you will still need to manually add your `fileSystems` and `swapDevices` blocks if you use this method.

## 5. Update Flake (Optional but Recommended)
Before running the install, you might want to ensure `flake.nix` or your host file (`wolverine.nix`) imports this new hardware file. 

If you've already added `imports = [ ./wolverine-hardware.nix ];` to your `wolverine.nix`, you can proceed.

## 6. Perform the Installation
Run the installer pointing to your flake on the mounted Work partition.

```bash
sudo nixos-install --flake /mnt/mnt/Work/1Progs/Dots/NixConfig#wolverine
```

## 7. Finalize
1. Set the root password if prompted.
2. Set your user password: `sudo nixos-enter --command "passwd anas"`
3. Reboot: `reboot`

## Post-Install Note
Your dotfiles are linked via `mkOutOfStoreSymlink` to `/mnt/Work/1Progs/Dots`. Since we mounted the `Work` partition, your configurations (Hyprland, Waybar, etc.) will be active immediately upon login.
