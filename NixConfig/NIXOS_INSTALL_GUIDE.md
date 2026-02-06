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

## 4. Perform the Installation
Run the installer pointing to your flake on the mounted Work partition.

```bash
sudo nixos-install --flake /mnt/mnt/Work/1Progs/Dots/NixConfig#wolverine
```

## 5. Finalize
1. Set the root password if prompted.
2. Set your user password: `sudo nixos-enter --command "passwd anas"`
3. Reboot: `reboot`

## Post-Install Note
Your dotfiles are linked via `mkOutOfStoreSymlink` to `/mnt/Work/1Progs/Dots`. Since we mounted the `Work` partition, your configurations (Hyprland, Waybar, etc.) will be active immediately upon login.
