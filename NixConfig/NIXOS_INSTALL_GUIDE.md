# NixOS Installation Guide (Live ISO, Wolverine + Mentalist)

All commands below are intended to run from the NixOS live ISO shell.

## 1. Boot the NixOS Live ISO
Boot from Ventoy and open a shell.

## 2. Format Target Partitions
Check device names first with `lsblk`.

```bash
# Example (adjust partitions for the current machine)
sudo mkfs.vfat -F 32 -n BOOT /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
```

## 3. Mount Install Target and Repo Separately
Do not mount `Work` inside `/mnt`. Keep it separate at `/mnt_work`.

```bash
# Install target
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/BOOT /mnt/boot

# Repo location (separate from install target)
sudo mkdir -p /mnt_work
sudo mount /dev/disk/by-label/Work /mnt_work
```

## 4. Set Repo Path
```bash
REPO=/mnt_work/1Progs/Dots/NixConfig
```

## 5. Generate Host Hardware File
`*-hardware.nix` is scanner-owned. Manual filesystems/swap are in host files.

```bash
# Wolverine
sudo nixos-generate-config --root /mnt --show-hardware-config --no-filesystems \
  > "$REPO/wolverine-hardware.nix"

# Mentalist
sudo nixos-generate-config --root /mnt --show-hardware-config --no-filesystems \
  > "$REPO/mentalist-hardware.nix"
```

## 6. Install (Choose Host)
```bash
# Wolverine
sudo nixos-install --root /mnt --flake "$REPO#wolverine" --accept-flake-config --keep-going

# Mentalist
sudo nixos-install --root /mnt --flake "$REPO#mentalist" --accept-flake-config --keep-going
```

## 7. Finalize
1. Set root password if prompted.
2. Set user password: `sudo nixos-enter --root /mnt --command "passwd anas"`.
3. Reboot: `reboot`.
