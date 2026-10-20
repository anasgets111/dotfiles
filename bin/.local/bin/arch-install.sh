#!/usr/bin/env bash
# Wolverine (Ryzen 5900X + RTX 3080) | Mentalist (Intel i9 13900H) | any new system
# From the Arch ISO:
# curl -fsSL -o arch-install.sh https://raw.githubusercontent.com/anasgets111/dotfiles/main/bin/.local/bin/arch-install.sh && bash arch-install.sh
# curl -fsSL -o arch-install.sh https://codeberg.org/anasgets111/dotfiles/raw/branch/main/bin/.local/bin/arch-install.sh && bash arch-install.sh
set -euo pipefail
trap 'printf "%b\n" "${RED:-}[ERROR]${COLOR_RESET:-} Command failed at line ${LINENO}: ${BASH_COMMAND:-unknown}"; exit 1' ERR

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

log_info() { printf '%b%s\n' "${BLUE}[INFO]${COLOR_RESET} " "$1"; }
log_success() { printf '%b%s\n' "${GREEN}[SUCCESS]${COLOR_RESET} " "$1"; }
log_warning() { printf '%b%s\n' "${YELLOW}[WARNING]${COLOR_RESET} " "$1"; }
log_error() { printf '%b%s\n' "${RED}[ERROR]${COLOR_RESET} " "$1"; }
log_step() { printf '\n%b%s%b\n' "${GREEN}=== " "$1" " ===${COLOR_RESET}"; }
die() {
    log_error "$1"
    exit 1
}

TIMEZONE="Africa/Cairo"
LOCALE="en_US.UTF-8"
VCONSOLE_KEYMAP="us"
USERNAME="anas"
USER_FULLNAME="Anas Khalifa"
WIFI_SSID="Ghuzlan_5G"
DOTS_DIR="/mnt/Work/1Progs/Dots"
DOTS_REMOTES=(https://github.com/anasgets111/dotfiles https://codeberg.org/anasgets111/dotfiles)
TARGET_ROOT="/mnt"
BTRFS_OPTS="noatime,compress=zstd:1"
OMARCHY_SIGNING_KEY="40DFB630FF42BCFFB047046CF0134EE680CAC571"
SCRIPT_PATH=$(realpath "${BASH_SOURCE[0]}")
# Known machines by /sys/class/dmi/id/product_name; anything else installs as a new system.
declare -A KNOWN_PRODUCTS=(["MS-7C94"]=Wolverine)

HOSTNAME=""
COMPOSITOR=""
NEXT_CHECKPOINT=""
BOOT_PARTITION=""
ROOT_PARTITION=""
# The only state file lives on the target root, so it exists once there is something to resume.
INSTALL_STATE_FILE="$TARGET_ROOT/root/install.state"
INSTALL_COMPLETE_MARKER="complete"
# Resume state is layout-specific; reject state written by a previous layout.
INSTALL_LAYOUT="btrfs-work-v2"

# Official repos (pacstrap)
COMMON_PACKAGES=(
    # Base
    base base-devel linux linux-firmware btrfs-progs networkmanager dnsmasq mandoc man-pages efibootmgr
    # Firmware / hardware
    bluez bluez-utils gnome-firmware i2c-tools lshw plymouth wireless-regdb zram-generator
    # Audio
    espeak-ng pipewire-alsa pipewire-jack pipewire-pulse speech-dispatcher wireplumber sound-theme-freedesktop
    # System
    gnome-keyring ly mkcert mold nautilus pacman-contrib pkgstats wl-clipboard wl-clip-persist wtype
    xdg-desktop-portal-gnome xdg-user-dirs qt5-wayland showmethekey cloudflared sshfs unixodbc
    # Shell
    bash-completion bat btop dysk expac eza fastfetch fd fish fnm fzf kitty starship tealdeer zoxide xsel
    # CLI
    7zip curl ffmpegthumbnailer git git-filter-repo git-lfs inotify-tools jq
    less neovim rate-mirrors rsync sassc shfmt stow stylua tokei tree-sitter-cli unzip unrar wget zip
    # Dev
    just openai-codex opencode podman rustup sccache yaak
    # Apps
    gnome-calculator gnome-disk-utility gnome-text-editor kdeconnect
    mission-center nautilus-image-converter papers qbittorrent simple-scan
    telegram-desktop thunderbird
    cava mpv-mpris satty zed
    # Theme / fonts
    kvantum qt6ct tela-circle-icon-theme-dracula
    adobe-source-code-pro-fonts gnu-free-fonts inter-font noto-fonts-emoji noto-fonts-extra opendesktop-fonts
    otf-font-awesome terminus-font ttf-bitstream-vera ttf-cascadia-code-nerd ttf-fira-code ttf-firacode-nerd ttf-liberation
    ttf-roboto-mono-nerd ttf-scheherazade-new ttf-jetbrains-mono-nerd
)
NVIDIA_PACKAGES=(nvidia-open nvidia-settings libva-nvidia-driver lib32-nvidia-utils)
INTEL_GPU_PACKAGES=(intel-media-driver vulkan-intel)
AMD_GPU_PACKAGES=(vulkan-radeon)
LAPTOP_PACKAGES=(brightnessctl sof-firmware)
HYPRLAND_PACKAGES=(hyprland hyprpicker hyprshot slurp uwsm xdg-desktop-portal-hyprland)
WOLVERINE_PACKAGES=(gamemode lib32-gamemode mangohud steam solaar openrgb)
MENTALIST_PACKAGES=(acpi_call pipewire-libcamera pipewire-v4l2)

# Chaotic-AUR / Omarchy (post-chroot)
COMMON_EXTRA_PACKAGES=(
    omarchy-keyring shellcheck-bin yay bibata-cursor-theme fish-autopair
    nautilus-code-git xdg-terminal-exec-git gpu-screen-recorder-git
    vesktop slack-desktop rustdesk-bin
    claude-code piper-tts-git voxtype-bin
    zen-browser-bin subliminal-git
    ttf-material-icons-git ttf-material-symbols-variable-git ttf-ms-fonts
)
WOLVERINE_EXTRA_PACKAGES=(heroic-games-launcher-bin helium-browser-bin)
MENTALIST_EXTRA_PACKAGES=(asusctl)
AUXILIARY_PARTITION_LABELS=(Work Media Games)

LIVE_STEPS=(
    choose_system
    ensure_network_connection
    prepare_disk
    mount_filesystems
    install_base_system
    generate_fstab
    run_target_configuration
)
TARGET_STEPS=(
    configure_system_basics
    install_bootloader
    configure_package_repositories
    configure_initramfs
    enable_system_services
    create_user_account
    bootstrap_user_environment
)

in_steps() {
    local n=$1
    shift
    [[ -n "$n" && " $* " == *" $n "* ]]
}

is_protected_partition() {
    local label
    label=$(blkid -s LABEL -o value "$1" 2>/dev/null || true)
    [[ -n "$label" && " ${AUXILIARY_PARTITION_LABELS[*]} Ventoy VTOYEFI " == *" $label "* ]]
}

# A disk is off limits when anything on it is mounted (the ISO, swap) or carries a protected label.
disk_in_use() {
    local part
    lsblk -nro MOUNTPOINT "$1" | grep -q . && return 0
    for part in $(lsblk -lnpo NAME "$1"); do
        is_protected_partition "$part" && return 0
    done
    return 1
}

unmount_target() {
    mountpoint -q "$TARGET_ROOT" || return 0
    cd /
    umount -R "$TARGET_ROOT"
}

mount_target() {
    mountpoint -q "$TARGET_ROOT" || mount -t btrfs -o "$BTRFS_OPTS,subvol=@" "$ROOT_PARTITION" "$TARGET_ROOT"
    mountpoint -q "$TARGET_ROOT/boot" || mount --mkdir -o noatime,umask=0077 "$BOOT_PARTITION" "$TARGET_ROOT/boot"
    mountpoint -q "$TARGET_ROOT/home" || mount --mkdir -t btrfs -o "$BTRFS_OPTS,subvol=@home" "$ROOT_PARTITION" "$TARGET_ROOT/home"
}

apply_pacman_defaults() {
    sed -i \
        -e 's/^#ParallelDownloads/ParallelDownloads/' \
        -e 's/^#Color/Color/' \
        -e '/\[multilib\]/,/Include/s/^#//' \
        "$1"
    grep -q "^ILoveCandy" "$1" || sed -i '/^Color/a ILoveCandy' "$1"
}

ensure_pacman_repo() {
    local pacman_config="$1" repo_name="$2"
    shift 2
    grep -q "^\[${repo_name}\]" "$pacman_config" && return 0
    printf '\n[%s]\n' "$repo_name" >>"$pacman_config"
    printf '%s\n' "$@" >>"$pacman_config"
}

run_as_user() { sudo -u "$USERNAME" -H -- bash -s -- "$@"; }

detect_hardware() {
    local dev
    CPU_VENDOR=$(awk -F: '/vendor_id/{print tolower($2); exit}' /proc/cpuinfo | xargs)
    GPU_VENDORS=""
    for dev in /sys/bus/pci/devices/*; do
        [[ "$(<"$dev/class")" == 0x03* ]] && GPU_VENDORS+=" $(<"$dev/vendor")"
    done
    IS_LAPTOP=0
    compgen -G '/sys/class/power_supply/BAT*' >/dev/null && IS_LAPTOP=1
    return 0
}

# Builds the package, service and stow lists from the hardware, compositor and hostname.
resolve_profile() {
    PACKAGES=() EXTRA_PACKAGES=() SERVICES=() INITRAMFS_MODULES=() STOW_PACKAGES=() USER_GROUPS=wheel,input
    case "$CPU_VENDOR" in
    *authenticamd*) PACKAGES+=(amd-ucode) ;;
    *genuineintel*) PACKAGES+=(intel-ucode) ;;
    esac
    # ponytail: hybrid Intel+NVIDIA laptops get both drivers but no PRIME offload setup.
    [[ "$GPU_VENDORS" == *0x10de* ]] && {
        PACKAGES+=("${NVIDIA_PACKAGES[@]}")
        SERVICES+=(nvidia-persistenced)
        INITRAMFS_MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
    }
    [[ "$GPU_VENDORS" == *0x8086* ]] && PACKAGES+=("${INTEL_GPU_PACKAGES[@]}")
    [[ "$GPU_VENDORS" == *0x1002* ]] && PACKAGES+=("${AMD_GPU_PACKAGES[@]}")
    ((IS_LAPTOP)) && PACKAGES+=("${LAPTOP_PACKAGES[@]}")
    if [[ "$COMPOSITOR" == hyprland ]]; then
        PACKAGES+=("${HYPRLAND_PACKAGES[@]}") STOW_PACKAGES=(hypr)
    else
        EXTRA_PACKAGES+=(niri-git) STOW_PACKAGES=(niri)
    fi
    case "$HOSTNAME" in
    Wolverine)
        PACKAGES+=("${WOLVERINE_PACKAGES[@]}") EXTRA_PACKAGES+=("${WOLVERINE_EXTRA_PACKAGES[@]}")
        USER_GROUPS+=,gamemode
        ;;
    Mentalist)
        PACKAGES+=("${MENTALIST_PACKAGES[@]}") EXTRA_PACKAGES+=("${MENTALIST_EXTRA_PACKAGES[@]}")
        SERVICES+=(asusd)
        ;;
    esac
}

valid_hostname() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; }

save_install_state() {
    [[ -d "${INSTALL_STATE_FILE%/*}" ]] || return 0
    (
        umask 077
        printf '%s\n' "$NEXT_CHECKPOINT" "$HOSTNAME" "$COMPOSITOR" "$BOOT_PARTITION" "$ROOT_PARTITION" "$INSTALL_LAYOUT" >"$INSTALL_STATE_FILE.tmp"
        mv -f -- "$INSTALL_STATE_FILE.tmp" "$INSTALL_STATE_FILE"
    )
}

load_install_state() {
    [[ -f "$INSTALL_STATE_FILE" && ! -L "$INSTALL_STATE_FILE" && -O "$INSTALL_STATE_FILE" ]] || return 1
    local -a fields
    mapfile -t fields <"$INSTALL_STATE_FILE"
    ((${#fields[@]} == 6)) && [[ "${fields[5]}" == "$INSTALL_LAYOUT" ]] || return 1
    valid_hostname "${fields[1]}" && [[ "${fields[2]}" == niri || "${fields[2]}" == hyprland ]] || return 1
    NEXT_CHECKPOINT="${fields[0]}" HOSTNAME="${fields[1]}" COMPOSITOR="${fields[2]}"
    BOOT_PARTITION="${fields[3]}" ROOT_PARTITION="${fields[4]}"
    detect_hardware
    resolve_profile
}

run_resumable_steps() {
    local step_functions=("$@") step_index=0
    [[ "$NEXT_CHECKPOINT" == "$INSTALL_COMPLETE_MARKER" ]] && return 0
    if [[ -n "$NEXT_CHECKPOINT" ]]; then
        for step_index in "${!step_functions[@]}"; do
            [[ "${step_functions[step_index]}" == "$NEXT_CHECKPOINT" ]] && break
        done
        [[ "${step_functions[step_index]}" == "$NEXT_CHECKPOINT" ]] || {
            log_error "Unknown resume checkpoint: $NEXT_CHECKPOINT"
            return 1
        }
    fi
    while ((step_index < ${#step_functions[@]})); do
        NEXT_CHECKPOINT="${step_functions[step_index]}"
        save_install_state
        "${step_functions[step_index]}"
        ((++step_index))
    done
    NEXT_CHECKPOINT="$INSTALL_COMPLETE_MARKER"
    save_install_state
}

# Mounts an existing Archlinux root and loads its state; leaves nothing mounted when there is none.
find_previous_install() {
    local root_partition
    root_partition=$(blkid -L Archlinux 2>/dev/null) || return 1
    mountpoint -q "$TARGET_ROOT" || mount -t btrfs -o "$BTRFS_OPTS,subvol=@" "$root_partition" "$TARGET_ROOT" 2>/dev/null || return 1
    load_install_state && [[ "$ROOT_PARTITION" == "$root_partition" ]] && return 0
    unmount_target
    return 1
}

import_iwd_wifi_into_nm() {
    local dest_dir="$1" iwd_dir="${2:-/var/lib/iwd}" psk_file ssid passphrase
    local -a psk_files=()
    shopt -s nullglob
    psk_files=("$iwd_dir"/*.psk)
    shopt -u nullglob
    ((${#psk_files[@]})) || return 0
    install -d -m 0700 "$dest_dir"
    for psk_file in "${psk_files[@]}"; do
        ssid=$(basename "$psk_file" .psk)
        [[ "$ssid" == =* ]] && continue
        passphrase=$(awk -F= '/^(Passphrase|PreSharedKey)=/{print substr($0, index($0, "=") + 1); exit}' "$psk_file")
        [[ -n "$passphrase" ]] || continue
        printf '%s\n' "[connection]" "id=$ssid" "type=wifi" "" "[wifi]" "ssid=$ssid" "hidden=true" "" \
            "[wifi-security]" "key-mgmt=wpa-psk" "psk=$passphrase" >"$dest_dir/${ssid}.nmconnection"
        chmod 600 "$dest_dir/${ssid}.nmconnection"
    done
}

select_from_menu() {
    local prompt=$1 default_index=$2 i reply
    shift 2
    local options=("$@")
    printf '%s\n' "$prompt" >/dev/tty
    for i in "${!options[@]}"; do
        printf '  %d) %s\n' $((i + 1)) "${options[i]}" >/dev/tty
    done
    while true; do
        read -rp "Choice [$((default_index + 1))]: " reply </dev/tty
        reply=${reply:-$((default_index + 1))}
        [[ "$reply" =~ ^[1-9][0-9]*$ ]] && ((reply >= 1 && reply <= ${#options[@]})) && break
    done
    printf '%s\n' $((reply - 1))
}

choose_system() {
    log_step "System"
    local product systems=(Wolverine Mentalist "New system") compositors=(niri hyprland) default=2 i
    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
    for i in 0 1; do
        [[ "${KNOWN_PRODUCTS[${product:-none}]:-}" == "${systems[i]}" ]] && default=$i
    done
    i=$(select_from_menu "Select system (product: ${product:-unknown})" "$default" "${systems[@]}")
    HOSTNAME=${systems[i]}
    if ((i == 2)); then
        HOSTNAME=""
        until valid_hostname "$HOSTNAME"; do
            read -rp "Hostname (letters, digits, hyphens): " HOSTNAME </dev/tty
        done
    fi
    default=0
    [[ "$HOSTNAME" == Wolverine ]] && default=1
    COMPOSITOR=${compositors[$(select_from_menu "Select compositor" "$default" "${compositors[@]}")]}
    detect_hardware
    resolve_profile
    log_success "$HOSTNAME | $COMPOSITOR | CPU:$CPU_VENDOR | GPU:${GPU_VENDORS:- none} | laptop:$IS_LAPTOP"
}

ensure_network_connection() {
    log_step "Checking connectivity"
    ping -c 1 -W 3 archlinux.org &>/dev/null && return 0
    local wifi_interface="" interface_path attempt=0 ssid wifi_passphrase
    log_warning "No internet connection detected"
    for interface_path in /sys/class/net/wl*; do
        [[ -e "$interface_path" ]] && {
            wifi_interface=$(basename "$interface_path")
            break
        }
    done
    [[ -n "$wifi_interface" ]] || die "No Wi-Fi interface detected."
    read -rp "Wi-Fi network [$WIFI_SSID]: " ssid </dev/tty
    ssid=${ssid:-$WIFI_SSID}
    read -rsp "Passphrase for $ssid: " wifi_passphrase </dev/tty
    printf '\n'
    iwctl station "$wifi_interface" scan
    sleep 3
    iwctl --passphrase "$wifi_passphrase" station "$wifi_interface" connect "$ssid" ||
        iwctl --passphrase "$wifi_passphrase" station "$wifi_interface" connect-hidden "$ssid"
    unset wifi_passphrase
    until ping -c 1 -W 3 archlinux.org &>/dev/null; do
        ((++attempt >= 20)) && die "Failed to connect after 20s. Please check manually."
        sleep 1
    done
    log_success "Connected to $ssid"
}

# Fresh system: GPT with BOOT (1 GiB), Archlinux (chosen size) and Work (the rest).
wipe_disk() {
    local -a disks=() options=() parts=()
    local disk size model disk_gib root_gib reply
    while read -r disk size model; do
        [[ "$disk" == /dev/zram* ]] || disk_in_use "$disk" && continue
        disks+=("$disk") options+=("$disk  $size  $model")
    done < <(lsblk -dnpo NAME,SIZE,MODEL -Q 'TYPE=="disk"')
    ((${#disks[@]})) || die "No disk free of mounted or protected partitions."
    disk=${disks[$(select_from_menu "Select disk to WIPE" 0 "${options[@]}")]}
    disk_gib=$(($(blockdev --getsize64 "$disk") >> 30))
    root_gib=$((disk_gib / 2 < 150 ? disk_gib / 2 : 150))
    while true; do
        read -rp "Root size in GiB; $disk is $disk_gib GiB, Work gets the rest [$root_gib]: " reply </dev/tty
        reply=${reply:-$root_gib}
        [[ "$reply" =~ ^[1-9][0-9]*$ ]] && ((reply >= 20 && reply <= disk_gib - 11)) && break
        log_warning "Pick 20 to $((disk_gib - 11)) GiB."
    done
    root_gib=$reply
    log_warning "This ERASES every partition on $disk!"
    read -rp "Type ${disk##*/} to confirm: " reply </dev/tty
    [[ "$reply" == "${disk##*/}" ]] || die "Aborted by user"
    sgdisk --zap-all "$disk"
    sgdisk -n1:0:+1G -t1:ef00 -n2:0:+"${root_gib}G" -t2:8300 -n3:0:0 -t3:8300 "$disk"
    udevadm settle
    mapfile -t parts < <(lsblk -lnpo NAME -Q 'TYPE=="part"' "$disk")
    ((${#parts[@]} == 3)) || die "Expected 3 partitions on $disk, found ${#parts[@]}."
    BOOT_PARTITION=${parts[0]} ROOT_PARTITION=${parts[1]}
    mkfs.ext4 -F -L Work "${parts[2]}"
}

select_partitions() {
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
    printf '\n'
    local -a partitions=()
    local raw_entry
    while IFS= read -r raw_entry; do
        is_protected_partition "${raw_entry%% *}" && continue
        partitions+=("$raw_entry")
    done < <(lsblk -lnpo NAME,SIZE,FSTYPE,LABEL -Q 'TYPE=="part"')
    ((${#partitions[@]})) || die "No eligible (unprotected) partitions found!"

    local current_boot current_root options=() boot_default=0 root_default=0 i
    current_boot=$(blkid -L BOOT 2>/dev/null || true)
    current_root=$(blkid -L Archlinux 2>/dev/null || true)
    for i in "${!partitions[@]}"; do
        local device="${partitions[i]%% *}" marker=""
        [[ "$device" == "$current_boot" ]] && marker=" [current BOOT]" boot_default=$i
        [[ "$device" == "$current_root" ]] && marker=" [current Archlinux]" root_default=$i
        options+=("${partitions[i]}$marker")
    done

    BOOT_PARTITION="${partitions[$(select_from_menu "Select BOOT partition" "$boot_default" "${options[@]}")]%% *}"
    while true; do
        ROOT_PARTITION="${partitions[$(select_from_menu "Select ROOT partition" "$root_default" "${options[@]}")]%% *}"
        [[ "$BOOT_PARTITION" != "$ROOT_PARTITION" ]] && break
        log_warning "BOOT and ROOT cannot be the same partition. Please choose again."
    done
    local response
    log_warning "This will ERASE $BOOT_PARTITION and $ROOT_PARTITION!"
    read -rp "Are you sure you want to continue? [y/N]: " response </dev/tty
    [[ "$response" =~ ^[Yy]$ ]] || die "Aborted by user"
}

prepare_disk() {
    log_step "Disk"
    local default=0
    [[ "$HOSTNAME" == Wolverine || "$HOSTNAME" == Mentalist ]] && default=1
    unmount_target
    if (($(select_from_menu "Disk setup" "$default" "Wipe a whole disk (BOOT, Archlinux, Work)" "Reuse existing partitions") == 0)); then
        wipe_disk
    else
        select_partitions
    fi
    log_info "Formatting $BOOT_PARTITION as FAT32, $ROOT_PARTITION as Btrfs with @ and @home"
    mkfs.fat -F32 -n BOOT "$BOOT_PARTITION"
    mkfs.btrfs -f -L Archlinux "$ROOT_PARTITION"
    mount -t btrfs -o subvolid=5 "$ROOT_PARTITION" "$TARGET_ROOT"
    btrfs subvolume create "$TARGET_ROOT/@" "$TARGET_ROOT/@home"
    umount "$TARGET_ROOT"
}

mount_filesystems() {
    log_step "Mounting filesystems"
    mount_target
    install -d -m 0700 "$TARGET_ROOT/root"
}

install_base_system() {
    log_step "Installing base system"
    reflector --country Germany,Austria,Italy,Netherlands,France \
        --latest 20 --protocol https --sort rate \
        --save /etc/pacman.d/mirrorlist --number 12
    apply_pacman_defaults /etc/pacman.conf
    pacman -Sy --noconfirm archlinux-keyring
    pacstrap -K "$TARGET_ROOT" "${COMMON_PACKAGES[@]}" "${PACKAGES[@]}"
}

# The auxiliary partitions are never mounted into the target, so genfstab leaves them to us.
generate_fstab() {
    log_step "Generating fstab"
    genfstab -L "$TARGET_ROOT" >"$TARGET_ROOT/etc/fstab"
    local label device
    for label in "${AUXILIARY_PARTITION_LABELS[@]}"; do
        device=$(blkid -L "$label" 2>/dev/null) || continue
        printf 'LABEL=%s  /mnt/%s  %s  nosuid,nodev,nofail,x-gvfs-show,x-systemd.makedir,noatime  0 0\n' \
            "$label" "$label" "$(blkid -s TYPE -o value "$device")" >>"$TARGET_ROOT/etc/fstab"
    done
}

run_target_configuration() {
    log_step "Preparing chroot"
    install -m 0755 "$SCRIPT_PATH" "$TARGET_ROOT/root/install.sh"
    cp /etc/pacman.d/mirrorlist "$TARGET_ROOT/etc/pacman.d/mirrorlist"
    apply_pacman_defaults "$TARGET_ROOT/etc/pacman.conf"
    import_iwd_wifi_into_nm "$TARGET_ROOT/etc/NetworkManager/system-connections"
    arch-chroot "$TARGET_ROOT" /root/install.sh chroot
}

configure_system_basics() {
    log_step "System basics"
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    hwclock --systohc
    sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
    locale-gen
    printf '%s\n' "LANG=$LOCALE" >/etc/locale.conf
    printf '%s\n' "KEYMAP=$VCONSOLE_KEYMAP" >/etc/vconsole.conf
    printf '%s\n' "$HOSTNAME" >/etc/hostname
    cat >/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF
    log_info "Set the root password"
    until passwd; do :; done
}

write_loader_entry() {
    printf '%s\n' "title   $2" "linux   /vmlinuz-linux" "initrd  $3" "options $4" >"/boot/loader/entries/$1"
}

install_bootloader() {
    log_step "Installing bootloader"
    bootctl --esp-path=/boot install
    cat >/boot/loader/loader.conf <<'EOF'
default arch.conf
timeout 0
console-mode max
editor no
EOF
    # zswap.enabled=0: zram wiki — zswap in front of zram intercepts pages.
    # microcode is embedded by the mkinitcpio microcode hook; no separate initrd line.
    local kernel_options="root=LABEL=Archlinux rootflags=subvol=@ rw quiet splash loglevel=3 nowatchdog zswap.enabled=0"
    write_loader_entry arch.conf "Arch Linux" /initramfs-linux.img "$kernel_options"
    write_loader_entry arch-fallback.conf "Arch Linux (fallback)" /initramfs-linux-fallback.img "$kernel_options"
    cat >/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
EOF
    cat >/etc/sysctl.d/99-zram.conf <<'EOF'
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
}

configure_package_repositories() {
    log_step "Additional repositories"
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com ||
        pacman-key --recv-key 3056513887B78AEB --keyserver hkp://keyserver.ubuntu.com:80
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --needed --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    ensure_pacman_repo /etc/pacman.conf chaotic-aur 'Include = /etc/pacman.d/chaotic-mirrorlist'
    pacman-key --recv-keys "$OMARCHY_SIGNING_KEY" --keyserver keys.openpgp.org
    pacman-key --lsign-key "$OMARCHY_SIGNING_KEY"
    # shellcheck disable=SC2016  # $arch is a pacman token
    ensure_pacman_repo /etc/pacman.conf omarchy \
        'SigLevel = Required DatabaseOptional' \
        'Server = https://pkgs.omarchy.org/edge/$arch'
    pacman -Syu --needed --noconfirm "${COMMON_EXTRA_PACKAGES[@]}" "${EXTRA_PACKAGES[@]}"
}

configure_initramfs() {
    log_step "Configuring initramfs"
    install -d /etc/mkinitcpio.conf.d
    cat >/etc/mkinitcpio.conf.d/99-mantle.conf <<EOF
MODULES=(${INITRAMFS_MODULES[*]})
HOOKS=(systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems)
EOF
    mkinitcpio -P
}

enable_system_services() {
    log_step "Enabling services"
    systemctl enable NetworkManager systemd-timesyncd fstrim.timer bluetooth ly@tty2 fwupd-refresh.timer "${SERVICES[@]}"
    sed -i \
        -e 's/^animation = none/animation = matrix/' \
        -e 's/^bigclock = none/bigclock = en/' \
        -e 's/^clock = .*/clock = %c/' \
        /etc/ly/config.ini
    ((IS_LAPTOP)) || return 0
    install -d /etc/systemd/logind.conf.d
    printf '%s\n' "[Login]" HandleLidSwitch=ignore HandleLidSwitchExternalPower=ignore HandleLidSwitchDocked=ignore \
        >/etc/systemd/logind.conf.d/lid.conf
}

create_user_account() {
    log_step "Creating user"
    if id -u "$USERNAME" &>/dev/null; then
        usermod -aG "$USER_GROUPS" "$USERNAME"
    else
        useradd -m -c "$USER_FULLNAME" -G "$USER_GROUPS" -s /usr/bin/fish "$USERNAME"
    fi
    log_info "Set the password for $USERNAME"
    until passwd "$USERNAME"; do :; done
    # logind is unreachable inside the chroot; linger is just this file, which
    # no package ships (logind mkdirs it at first boot).
    install -d /var/lib/systemd/linger
    touch "/var/lib/systemd/linger/$USERNAME"
    install -d -m 0750 /etc/sudoers.d
    printf '%s\n' '%wheel ALL=(ALL:ALL) ALL' >/etc/sudoers.d/10-wheel
    chmod 440 /etc/sudoers.d/10-wheel
}

bootstrap_user_environment() {
    log_step "Post-install user bootstrap"
    mountpoint -q /mnt/Work || mount --mkdir /mnt/Work || die "Failed to mount /mnt/Work."
    chown "$USERNAME:" /mnt/Work
    if [[ ! -d "$DOTS_DIR" ]]; then
        # shellcheck disable=SC2016  # expanded by the user shell
        run_as_user "$DOTS_DIR" "${DOTS_REMOTES[@]}" <<<'git clone "$2" "$1" || git clone "$3" "$1"'
    fi

    # backup-home exits early without its backup, so a fresh system skips it.
    if [[ -d /mnt/Work/Home_backup ]] && ! sudo -u "$USERNAME" -H -- "$DOTS_DIR/bin/.local/bin/backup-home" -r; then
        log_warning "backup-home restore failed; continuing."
    fi

    systemctl --global enable podman.socket podman-restart.service

    run_as_user "$DOTS_DIR" home config bin xdg-desktop-portal kitty mantle fish nvim mpv \
        "${STOW_PACKAGES[@]}" <<'SCRIPT'
		rm -f "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.bash_logout"
		# Without a real ~/.local, stow folds the whole dir into the repo and apps write their data there.
		mkdir -p "$HOME/.local"
		for pkg in fish kitty mantle nvim mpv hypr niri xdg-desktop-portal; do
			target="$HOME/.config/$pkg"
			[[ -e "$target" && ! -L "$target" ]] && rm -rf "$target"
		done
		cd "$1" && shift && stow -R -t "$HOME" "$@"
SCRIPT

    # The backup restores a cargo-built mantle; only a system without one needs the package.
    local aur_packages=(antigravity-cli)
    [[ -x "/home/$USERNAME/.local/share/cargo/bin/mantle" ]] || aur_packages+=(mantle-bin)
    local sudoers_tmp=/etc/sudoers.d/99-installer-temp
    printf '%s\n' "$USERNAME ALL=(ALL) NOPASSWD: ALL" >"$sudoers_tmp"
    chmod 440 "$sudoers_tmp"
    trap 'rm -f -- "$sudoers_tmp"' EXIT
    run_as_user "${aur_packages[@]}" <<<'yay -S --needed --noconfirm --removemake --cleanafter "$@"'
    rm -f -- "$sudoers_tmp"
    trap - EXIT

    "$DOTS_DIR/bin/.local/bin/setup-reboot-required" || log_warning "Failed to install reboot-required hook; continuing."
}

live_main() {
    ((EUID == 0)) || die "Run this script as root from the Arch live ISO."
    [[ -d /sys/firmware/efi/efivars ]] || die "Not booted in UEFI mode. The install uses systemd-boot."

    if find_previous_install; then
        local resume_reply
        read -rp "Resume previous install of $HOSTNAME at $NEXT_CHECKPOINT? [Y/n] " resume_reply </dev/tty
        if [[ "$resume_reply" =~ ^[Nn] ]]; then
            rm -f "$INSTALL_STATE_FILE"
            unmount_target
            NEXT_CHECKPOINT=""
        else
            mount_target
        fi
    fi

    if in_steps "$NEXT_CHECKPOINT" "${TARGET_STEPS[@]}"; then
        run_target_configuration
    else
        run_resumable_steps "${LIVE_STEPS[@]}"
    fi

    log_success "Installation complete"
    rm -f "$INSTALL_STATE_FILE"
    printf '\n'
    read -rsn1 -p "Press any key to unmount and reboot (Ctrl+C to cancel)..." </dev/tty
    printf '\n'
    umount -R "$TARGET_ROOT" 2>/dev/null || true
    sleep 2
    reboot
}

target_main() {
    INSTALL_STATE_FILE="/root/install.state"
    load_install_state || die "Missing or invalid chroot installation state"
    in_steps "$NEXT_CHECKPOINT" "${TARGET_STEPS[@]}" || NEXT_CHECKPOINT=""
    run_resumable_steps "${TARGET_STEPS[@]}"
    rm -f /root/install.sh
    log_success "Target configuration complete"
}

self_check() {
    local dir
    dir=$(mktemp -d)

    CPU_VENDOR=authenticamd GPU_VENDORS=" 0x10de" IS_LAPTOP=0 HOSTNAME=Wolverine COMPOSITOR=hyprland
    resolve_profile
    [[ " ${PACKAGES[*]} " == *" amd-ucode nvidia-open "*" slurp "*" steam "* && "${STOW_PACKAGES[*]}" == hypr ]]
    [[ "${SERVICES[*]}" == nvidia-persistenced && ${#INITRAMFS_MODULES[@]} == 4 && "$USER_GROUPS" == wheel,input,gamemode ]]
    CPU_VENDOR=genuineintel GPU_VENDORS=" 0x8086" IS_LAPTOP=1 HOSTNAME=Scratch COMPOSITOR=niri
    resolve_profile
    [[ "${PACKAGES[*]}" == "intel-ucode ${INTEL_GPU_PACKAGES[*]} ${LAPTOP_PACKAGES[*]}" && "${EXTRA_PACKAGES[*]}" == niri-git ]]
    [[ ${#SERVICES[@]} == 0 && ${#INITRAMFS_MODULES[@]} == 0 && "$USER_GROUPS" == wheel,input ]]

    INSTALL_STATE_FILE="$dir/install.state"
    detect_hardware() { :; }
    NEXT_CHECKPOINT=enable_system_services BOOT_PARTITION=/dev/example1 ROOT_PARTITION=/dev/example2
    save_install_state
    [[ "$(stat -c '%a' "$INSTALL_STATE_FILE")" == 600 ]]
    NEXT_CHECKPOINT="" HOSTNAME="" COMPOSITOR=""
    load_install_state
    [[ "$NEXT_CHECKPOINT $HOSTNAME $COMPOSITOR $ROOT_PARTITION" == "enable_system_services Scratch niri /dev/example2" ]]
    printf '%s\n' x 'bad host!' niri /dev/a /dev/b "$INSTALL_LAYOUT" >"$INSTALL_STATE_FILE"
    load_install_state && die "Self-check accepted an invalid hostname"
    printf '%s\n' x Scratch niri /dev/a /dev/b old-layout >"$INSTALL_STATE_FILE"
    load_install_state && die "Self-check accepted an old layout"

    local step_log="$dir/steps.log"
    _sc1() { printf '%s\n' one >>"$step_log"; }
    _sc2() { printf '%s\n' two >>"$step_log"; }
    NEXT_CHECKPOINT=_sc2
    run_resumable_steps _sc1 _sc2
    [[ "$(<"$step_log")" == two && "$NEXT_CHECKPOINT" == "$INSTALL_COMPLETE_MARKER" ]]

    local pacman_fixture="$dir/pacman.conf"
    printf '%s\n' '[options]' '#Color' '#ParallelDownloads = 5' '' '#[multilib]' '#Include = /etc/pacman.d/mirrorlist' >"$pacman_fixture"
    apply_pacman_defaults "$pacman_fixture"
    apply_pacman_defaults "$pacman_fixture"
    ensure_pacman_repo "$pacman_fixture" chaotic-aur 'Include = /etc/pacman.d/chaotic-mirrorlist'
    ensure_pacman_repo "$pacman_fixture" chaotic-aur 'Include = /etc/pacman.d/chaotic-mirrorlist'
    [[ "$(grep -cE '^(Color|ILoveCandy|ParallelDownloads = 5|\[multilib\]|\[chaotic-aur\])$' "$pacman_fixture")" == 5 ]]

    install -d "$dir/iwd"
    printf '%s\n' '[Security]' 'Passphrase=secret=value' >"$dir/iwd/Ghuzlan_5G.psk"
    import_iwd_wifi_into_nm "$dir/nm" "$dir/iwd"
    local nm="$dir/nm/Ghuzlan_5G.nmconnection"
    [[ "$(stat -c '%a' "$nm")" == 600 && "$(grep -cE '^(ssid=Ghuzlan_5G|psk=secret=value)$' "$nm")" == 2 ]]

    rm -rf -- "$dir"
    log_success "Self-check passed"
}

case "${1:-}" in
chroot) target_main ;;
--self-check) self_check ;;
*) live_main ;;
esac
