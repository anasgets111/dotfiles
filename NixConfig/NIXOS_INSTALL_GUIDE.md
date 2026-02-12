# NixOS Installation Guide (Live ISO, Wolverine + Mentalist, 25.11+)

All commands below are intended to run from the NixOS live ISO shell.

## Current Layout

After the refactor, host and module files are split as:

```text
NixConfig/
  flake.nix
  hosts/
    Wolverine/
      default.nix
      hardware-config.nix
    Mentalist/
      default.nix
      hardware-config.nix
  modules/
    common.nix
    home.nix
    php.nix
    containers.nix
```

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

`hardware-config.nix` is scanner-owned. Manual filesystems/swap are in host `default.nix`.

```bash
# Wolverine
sudo nixos-generate-config --root /mnt --show-hardware-config --no-filesystems \
  > "$REPO/hosts/Wolverine/hardware-config.nix"

# Mentalist
sudo nixos-generate-config --root /mnt --show-hardware-config --no-filesystems \
  > "$REPO/hosts/Mentalist/hardware-config.nix"
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

## 8. Arch Linux: Install Nix (for local flake validation)

Run these on your Arch machine after booting into your normal system.

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
```

Start a new shell session, then ensure flakes are enabled:

```bash
mkdir -p ~/.config/nix
printf "experimental-features = nix-command flakes\n" >> ~/.config/nix/nix.conf
```

## 9. Post-Refactor Validation

Run from the `NixConfig/` directory on Arch after Nix is installed.

```bash
nix flake check --no-build
nix build .#nixosConfigurations.wolverine.config.system.build.toplevel
nix build .#nixosConfigurations.mentalist.config.system.build.toplevel
```

## References (25.11+ compatible)

- Nix download/install: <https://nixos.org/download>
- NixOS stable release notes: <https://nixos.org/manual/nixos/stable/release-notes>
- NixOS unstable release notes: <https://nixos.org/manual/nixos/unstable/release-notes>
