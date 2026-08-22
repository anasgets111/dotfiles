#!/usr/bin/env bash
# Wolverine (Ryzen 5900X + RTX 3080) | Mentalist (Intel i9 13900H)
# From the Arch ISO:
# curl -fsSL -o arch-install.sh https://raw.githubusercontent.com/anasgets111/dotfiles/main/bin/.local/bin/arch-install.sh && bash arch-install.sh
# curl -fsSL -o arch-install.sh https://codeberg.org/anasgets111/dotfiles/raw/branch/main/bin/.local/bin/arch-install.sh && bash arch-install.sh
set -euo pipefail
trap 'printf "%b\n" "${RED:-}[ERROR]${COLOR_RESET:-} Command failed at line ${LINENO}: ${BASH_COMMAND:-unknown}"; exit 1' ERR

# Relocate outside mounted filesystems so the script survives unmounts.
RUNTIME_DIR="/run/arch-install"
RUNTIME_SCRIPT="$RUNTIME_DIR/install.sh"
if [[ "${1:-}" != "chroot" && "${1:-}" != "--self-check" && "$(dirname "$(realpath "$0")" 2>/dev/null)" != "$RUNTIME_DIR" && -f "$0" ]]; then
    install -d -m 0700 "$RUNTIME_DIR"
    install -m 0755 "$0" "$RUNTIME_SCRIPT"
    exec "$RUNTIME_SCRIPT" "$@"
fi

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
TARGET_ROOT="/mnt"
OMARCHY_SIGNING_KEY="40DFB630FF42BCFFB047046CF0134EE680CAC571"
IN_CHROOT=0

SYSTEM_PROFILE=""
HOSTNAME=""
NEXT_CHECKPOINT=""
INSTALL_STATE_FILE="$RUNTIME_DIR/state"
INSTALL_COMPLETE_MARKER="complete"
# Resume state is layout-specific; reject state written by a previous root layout.
INSTALL_LAYOUT="btrfs-subvolumes-v1"
BOOT_PARTITION=""
ROOT_PARTITION=""

# Official repos (pacstrap)
COMMON_PACKAGES=(
    # Base
    base base-devel linux linux-firmware btrfs-progs networkmanager dnsmasq mandoc man-pages efibootmgr
    # Firmware / hardware
    bluez bluez-utils gnome-firmware i2c-tools lshw plymouth wireless-regdb zram-generator
    # Audio
    espeak-ng pipewire-alsa pipewire-jack pipewire-pulse speech-dispatcher wireplumber
    # System
    gnome-keyring ly mkcert mold nautilus pacman-contrib pkgstats wl-clipboard wl-clip-persist wtype
    xdg-desktop-portal-gnome xdg-user-dirs qt5-wayland showmethekey cloudflared
    # Shell
    bash-completion bat btop dysk expac eza fastfetch fd fish fnm fzf kitty starship tealdeer zoxide xsel
    # CLI
    7zip curl ffmpegthumbnailer git git-filter-repo git-lfs inotify-tools jq
    less neovim rate-mirrors rsync sassc shfmt stow stylua tokei tree-sitter-cli unzip unrar wget zip
    # Dev
    just openai-codex opencode rustup yaak
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

MENTALIST_PACKAGES=(
    acpi_call brightnessctl intel-media-driver intel-ucode sof-firmware vulkan-intel
    pipewire-libcamera pipewire-v4l2
    unixodbc
)

WOLVERINE_PACKAGES=(
    amd-ucode lib32-gamemode lib32-nvidia-utils libva-nvidia-driver nvidia-open nvidia-settings
    hyprland hyprpicker hyprshot uwsm xdg-desktop-portal-hyprland
    gamemode mangohud steam
    solaar openrgb
)

# Chaotic-AUR / Omarchy (post-chroot)
COMMON_EXTRA_PACKAGES=(
    omarchy-keyring shellcheck-bin yay bibata-cursor-theme fish-autopair
    nautilus-code-git xdg-terminal-exec-git gpu-screen-recorder-git quickshell-git
    vesktop slack-desktop rustdesk-bin
    claude-code piper-tts-git voxtype-bin
    zen-browser-bin subliminal-git
    ttf-material-icons-git ttf-material-symbols-variable-git ttf-ms-fonts
)

MENTALIST_EXTRA_PACKAGES=(asusctl niri-git)
WOLVERINE_EXTRA_PACKAGES=(heroic-games-launcher-bin helium-browser-bin)
AUXILIARY_PARTITION_LABELS=(Work Media Games)

LIVE_STEPS=(
    detect_system_profile
    ensure_network_connection
    select_partitions
    confirm_and_format_partitions
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

unmount_target() {
    mountpoint -q "$TARGET_ROOT" || return 0
    cd /
    umount -R "$TARGET_ROOT"
}

set_password_with_retry() {
    local target_label="$1" attempt
    shift
    for attempt in 1 2 3; do
        log_info "Set password for $target_label (attempt $attempt/3)"
        "$@" && return 0
        log_warning "Password setup failed for $target_label."
    done
    die "Failed to set password for $target_label after 3 attempts."
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

apply_system_profile() {
    case "$SYSTEM_PROFILE" in
    wolverine)
        HOSTNAME=Wolverine PROFILE_GROUPS=wheel,input,gamemode PROFILE_WAYLAND_SESSION=hyprland-uwsm.desktop
        PROFILE_SERVICES=(nvidia-persistenced) PROFILE_STOW_PACKAGES=(hypr)
        PROFILE_INITRAMFS_MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
        ;;
    mentalist)
        HOSTNAME=Mentalist PROFILE_GROUPS=wheel,input PROFILE_WAYLAND_SESSION=niri.desktop
        PROFILE_SERVICES=(asusd) PROFILE_STOW_PACKAGES=(niri)
        PROFILE_INITRAMFS_MODULES=()
        ;;
    *)
        log_error "Unknown system profile: ${SYSTEM_PROFILE:-<empty>}"
        return 1
        ;;
    esac
    local -n _pkgs="${SYSTEM_PROFILE^^}_PACKAGES" _extra="${SYSTEM_PROFILE^^}_EXTRA_PACKAGES"
    PROFILE_PACKAGES=("${_pkgs[@]}")
    PROFILE_EXTRA_PACKAGES=("${_extra[@]}")
}

save_install_state() {
    local dests=("$INSTALL_STATE_FILE") dest
    if [[ "$IN_CHROOT" != 1 && "$INSTALL_STATE_FILE" == "$RUNTIME_DIR/state" ]] && mountpoint -q "$TARGET_ROOT" && [[ -d "$TARGET_ROOT/usr" && -d "$TARGET_ROOT/root" ]]; then
        dests+=("$TARGET_ROOT/root/install.state")
    fi
    for dest in "${dests[@]}"; do
        (
            umask 077
            printf '%s\n' "$NEXT_CHECKPOINT" "$SYSTEM_PROFILE" "$BOOT_PARTITION" "$ROOT_PARTITION" "$INSTALL_LAYOUT" >"$dest.tmp"
            mv -f -- "$dest.tmp" "$dest"
        )
    done
}

load_install_state() {
    [[ -f "$INSTALL_STATE_FILE" && ! -L "$INSTALL_STATE_FILE" && -O "$INSTALL_STATE_FILE" ]] || return 1
    local -a state_fields
    mapfile -t state_fields <"$INSTALL_STATE_FILE"
    ((${#state_fields[@]} == 5)) || return 1
    [[ "${state_fields[1]}" == wolverine || "${state_fields[1]}" == mentalist ]] || return 1
    [[ "${state_fields[4]}" == "$INSTALL_LAYOUT" ]] || return 1
    NEXT_CHECKPOINT="${state_fields[0]}"
    SYSTEM_PROFILE="${state_fields[1]}"
    BOOT_PARTITION="${state_fields[2]}"
    ROOT_PARTITION="${state_fields[3]}"
    apply_system_profile
}

clear_install_state() {
    rm -f "$INSTALL_STATE_FILE"
    if [[ "$IN_CHROOT" != 1 ]] && mountpoint -q "$TARGET_ROOT"; then
        rm -f "$TARGET_ROOT/root/install.state"
    fi
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

ensure_target_mounted() {
    [[ -b "$BOOT_PARTITION" && -b "$ROOT_PARTITION" && "$BOOT_PARTITION" != "$ROOT_PARTITION" ]] || return 1
    mountpoint -q "$TARGET_ROOT" || mount -o noatime,compress=zstd:1,subvol=@ "$ROOT_PARTITION" "$TARGET_ROOT" || return 1
    mountpoint -q "$TARGET_ROOT/boot" || mount --mkdir -o noatime,umask=0077 "$BOOT_PARTITION" "$TARGET_ROOT/boot" || return 1
    mountpoint -q "$TARGET_ROOT/home" || mount --mkdir -o noatime,compress=zstd:1,subvol=@home "$ROOT_PARTITION" "$TARGET_ROOT/home" || return 1
    local work_partition
    work_partition=$(blkid -L Work || true)
    [[ -n "$work_partition" ]] || return 1
    mountpoint -q "$TARGET_ROOT/mnt/Work" || mount --mkdir -o noatime "$work_partition" "$TARGET_ROOT/mnt/Work" || return 1
}

recover_state_from_target() {
    local root_partition mounted_here=0
    root_partition=$(blkid -L Archlinux 2>/dev/null || true)
    [[ -b "$root_partition" ]] || return 1
    install -d "$TARGET_ROOT"
    if ! mountpoint -q "$TARGET_ROOT"; then
        mount -o noatime,compress=zstd:1,subvol=@ "$root_partition" "$TARGET_ROOT" || return 1
        mounted_here=1
    fi
    INSTALL_STATE_FILE="$TARGET_ROOT/root/install.state"
    if load_install_state; then
        INSTALL_STATE_FILE="$RUNTIME_DIR/state"
        save_install_state
        return 0
    fi
    ((mounted_here)) && umount "$TARGET_ROOT"
    INSTALL_STATE_FILE="$RUNTIME_DIR/state"
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
        cat >"$dest_dir/${ssid}.nmconnection" <<EOF
[connection]
id=$ssid
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$ssid
hidden=true

[wifi-security]
key-mgmt=wpa-psk
psk=$passphrase

[ipv4]
method=auto

[ipv6]
method=auto
EOF
        chmod 600 "$dest_dir/${ssid}.nmconnection"
    done
}

detect_system_profile() {
    log_step "Detecting target system"
    local cpu_vendor
    cpu_vendor=$(awk -F: '/vendor_id/{print tolower($2); exit}' /proc/cpuinfo | xargs)
    case "$cpu_vendor" in
    *authenticamd*) SYSTEM_PROFILE="wolverine" ;;
    *genuineintel*) SYSTEM_PROFILE="mentalist" ;;
    *) die "Unsupported CPU vendor: ${cpu_vendor:-unknown} (need AMD or Intel)" ;;
    esac
    apply_system_profile
    log_success "Auto-detected: $HOSTNAME"
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

ensure_network_connection() {
    log_step "Checking connectivity"
    if ping -c 1 -W 3 archlinux.org &>/dev/null; then
        return 0
    fi
    local wifi_interface="" interface_path attempt=0 wifi_passphrase
    log_warning "No internet connection detected"
    for interface_path in /sys/class/net/wl*; do
        [[ -e "$interface_path" ]] && {
            wifi_interface=$(basename "$interface_path")
            break
        }
    done
    [[ -n "$wifi_interface" ]] || die "No Wi-Fi interface detected."
    log_info "Connecting $wifi_interface to $WIFI_SSID"
    read -rsp "Enter Wi-Fi passphrase: " wifi_passphrase </dev/tty
    printf '\n'
    iwctl --passphrase "$wifi_passphrase" station "$wifi_interface" connect-hidden "$WIFI_SSID"
    unset wifi_passphrase
    until ping -c 1 -W 3 archlinux.org &>/dev/null; do
        ((++attempt >= 20)) && die "Failed to connect after 20s. Please check manually."
        sleep 1
    done
    log_success "Connected to Wi-Fi"
}

select_partitions() {
    log_step "Partition selection"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
    printf '\n'

    local -a partitions=()
    local raw_entry
    while IFS= read -r raw_entry; do
        is_protected_partition "${raw_entry%% *}" && continue
        partitions+=("$raw_entry")
    done < <(lsblk -lnpo NAME,SIZE,FSTYPE,LABEL -Q 'TYPE=="part"')
    ((${#partitions[@]})) || die "No eligible (unprotected) partitions found!"

    local current_boot current_root
    current_boot=$(blkid -L BOOT 2>/dev/null || true)
    current_root=$(blkid -L Archlinux 2>/dev/null || true)

    local partition_options=() boot_default_index=0 root_default_index=0 i
    for i in "${!partitions[@]}"; do
        local partition_device="${partitions[$i]%% *}" marker=""
        if [[ "$partition_device" == "$current_boot" ]]; then
            marker=" [current BOOT]"
            boot_default_index=$i
        elif [[ "$partition_device" == "$current_root" ]]; then
            marker=" [current Archlinux]"
            root_default_index=$i
        fi
        partition_options+=("${partitions[$i]}$marker")
    done

    BOOT_PARTITION="${partitions[$(select_from_menu "Select BOOT partition" "$boot_default_index" "${partition_options[@]}")]%% *}"
    while true; do
        ROOT_PARTITION="${partitions[$(select_from_menu "Select ROOT partition" "$root_default_index" "${partition_options[@]}")]%% *}"
        [[ "$BOOT_PARTITION" != "$ROOT_PARTITION" ]] && break
        log_warning "BOOT and ROOT cannot be the same partition. Please choose again."
    done
    log_success "Selected: BOOT=$BOOT_PARTITION, ROOT=$ROOT_PARTITION"
}

confirm_and_format_partitions() {
    log_step "Formatting partitions"
    local boot_details root_details response
    boot_details=$(lsblk -dno SIZE,FSTYPE,LABEL "$BOOT_PARTITION" 2>/dev/null | xargs)
    root_details=$(lsblk -dno SIZE,FSTYPE,LABEL "$ROOT_PARTITION" 2>/dev/null | xargs)
    printf 'Hostname: %s\nBoot: %s (%s)\nRoot: %s (%s)\nUser: %s\nTimezone: %s\nLocale: %s\n' \
        "$HOSTNAME" "$BOOT_PARTITION" "${boot_details:-boot}" "$ROOT_PARTITION" "${root_details:-root}" \
        "$USERNAME" "$TIMEZONE" "$LOCALE"
    if is_protected_partition "$BOOT_PARTITION" || is_protected_partition "$ROOT_PARTITION"; then
        die "Refusing to format protected partition (Work/Media/Games/Ventoy)!"
    fi
    log_warning "This will ERASE all data on $BOOT_PARTITION (${boot_details:-boot}) and $ROOT_PARTITION (${root_details:-root})!"
    read -rp "Are you sure you want to continue? [y/N]: " response </dev/tty
    [[ "$response" =~ ^[Yy]$ ]] || die "Aborted by user"
    [[ -b "$BOOT_PARTITION" && -b "$ROOT_PARTITION" && "$BOOT_PARTITION" != "$ROOT_PARTITION" ]] ||
        die "Saved partition selection is no longer valid. Start a new install."
    if mountpoint -q "$TARGET_ROOT"; then
        unmount_target || die "Failed to unmount $TARGET_ROOT. Resolve busy mounts and retry."
    fi
    log_info "Formatting BOOT as FAT32, ROOT as Btrfs with @ and @home subvolumes"
    mkfs.fat -F32 -n BOOT "$BOOT_PARTITION"
    mkfs.btrfs -f -L Archlinux "$ROOT_PARTITION"
    mount -o subvolid=5 "$ROOT_PARTITION" "$TARGET_ROOT"
    btrfs subvolume create "$TARGET_ROOT/@"
    btrfs subvolume create "$TARGET_ROOT/@home"
    umount "$TARGET_ROOT"
}

mount_filesystems() {
    log_step "Mounting filesystems"
    unmount_target
    ensure_target_mounted || die "Failed to mount target filesystems."
    install -d -m 0700 "$TARGET_ROOT/root"
}

install_base_system() {
    log_step "Installing base system"
    ensure_target_mounted || die "Failed to mount target filesystems."
    reflector --country Germany,Austria,Italy,Netherlands,France \
        --latest 20 --protocol https --sort rate \
        --save /etc/pacman.d/mirrorlist --number 12
    apply_pacman_defaults /etc/pacman.conf
    pacman -Sy --noconfirm archlinux-keyring
    pacstrap -K "$TARGET_ROOT" "${COMMON_PACKAGES[@]}" "${PROFILE_PACKAGES[@]}"
}

generate_fstab() {
    log_step "Generating fstab"
    ensure_target_mounted || die "Failed to mount target filesystems."
    genfstab -L "$TARGET_ROOT" >"$TARGET_ROOT/etc/fstab"
    local mount_opts="nosuid,nodev,nofail,x-gvfs-show,x-systemd.makedir,noatime"
    local label device fstype entry
    for label in "${AUXILIARY_PARTITION_LABELS[@]}"; do
        device=$(blkid -L "$label" 2>/dev/null || true)
        [[ -n "$device" ]] || continue
        fstype=$(blkid -s TYPE -o value "$device" || true)
        [[ -n "$fstype" ]] || continue
        entry="LABEL=$label  /mnt/$label  $fstype  $mount_opts  0 0"
        if grep -qE "^[[:space:]]*LABEL=${label}[[:space:]]+" "$TARGET_ROOT/etc/fstab"; then
            sed -i "s|^[[:space:]]*LABEL=${label}[[:space:]].*|$entry|" "$TARGET_ROOT/etc/fstab"
        else
            printf '%s\n' "$entry" >>"$TARGET_ROOT/etc/fstab"
        fi
    done
}

run_target_configuration() {
    log_step "Preparing chroot"
    ensure_target_mounted || die "Failed to mount target filesystems."
    install -m 0755 "$RUNTIME_SCRIPT" "$TARGET_ROOT/root/install.sh"
    cp /etc/pacman.d/mirrorlist "$TARGET_ROOT/etc/pacman.d/mirrorlist"
    apply_pacman_defaults "$TARGET_ROOT/etc/pacman.conf"
    import_iwd_wifi_into_nm "$TARGET_ROOT/etc/NetworkManager/system-connections"
    # If chroot progresses, mirror its checkpoint back into /run so a same-ISO retry
    # doesn't rewind from stale state.
    if arch-chroot "$TARGET_ROOT" /root/install.sh chroot; then
        :
    else
        [[ -f "$TARGET_ROOT/root/install.state" ]] && cp -p "$TARGET_ROOT/root/install.state" "$INSTALL_STATE_FILE"
        return 1
    fi
    [[ -f "$TARGET_ROOT/root/install.state" ]] && cp -p "$TARGET_ROOT/root/install.state" "$INSTALL_STATE_FILE"
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
    set_password_with_retry "root" passwd
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
    pacman -Syu --needed --noconfirm "${COMMON_EXTRA_PACKAGES[@]}" "${PROFILE_EXTRA_PACKAGES[@]}"
}

configure_initramfs() {
    log_step "Configuring initramfs"
    install -d /etc/mkinitcpio.conf.d
    cat >/etc/mkinitcpio.conf.d/99-obelisk.conf <<EOF
MODULES=(${PROFILE_INITRAMFS_MODULES[*]})
HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)
EOF
    mkinitcpio -P
}

enable_system_services() {
    log_step "Enabling services"
    systemctl enable NetworkManager systemd-timesyncd fstrim.timer bluetooth ly@tty2 fwupd-refresh.timer "${PROFILE_SERVICES[@]}"
    systemctl disable getty@tty2.service 2>/dev/null || true
    sed -i \
        -e 's/^animation = none/animation = matrix/' \
        -e 's/^bigclock = none/bigclock = en/' \
        -e 's/^clock = .*/clock = %c/' \
        /etc/ly/config.ini 2>/dev/null || true
    local session_src="/usr/share/wayland-sessions/${PROFILE_WAYLAND_SESSION}"
    if [[ -f "$session_src" ]]; then
        install -d /etc/ly/wayland-sessions
        ln -sfn "$session_src" "/etc/ly/wayland-sessions/$PROFILE_WAYLAND_SESSION"
        sed -i "s|^waylandsessions = .*|waylandsessions = /etc/ly/wayland-sessions|" /etc/ly/config.ini
    fi
}

create_user_account() {
    log_step "Creating user"
    if id -u "$USERNAME" &>/dev/null; then
        usermod -aG "$PROFILE_GROUPS" "$USERNAME"
    else
        useradd -m -c "$USER_FULLNAME" -G "$PROFILE_GROUPS" -s /usr/bin/fish "$USERNAME"
    fi
    set_password_with_retry "$USERNAME" passwd "$USERNAME"
    install -d -m 0750 /etc/sudoers.d
    printf '%s\n' '%wheel ALL=(ALL:ALL) ALL' >/etc/sudoers.d/10-wheel
    chmod 440 /etc/sudoers.d/10-wheel
}

bootstrap_user_environment() {
    log_step "Post-install user bootstrap"
    local dots=/mnt/Work/1Progs/Dots
    mountpoint -q /mnt/Work || mount --mkdir /mnt/Work || die "Failed to mount /mnt/Work."
    [[ -d "$dots" ]] || die "Dots directory not found at $dots."

    if [[ ! -x "$dots/bin/.local/bin/backup-home" ]] ||
        ! sudo -u "$USERNAME" -H -- "$dots/bin/.local/bin/backup-home" -r; then
        log_warning "backup-home restore failed (or script missing); continuing."
    fi

    sudo -u "$USERNAME" -H -- xdg-user-dirs-update

    run_as_user "$dots" home config bin xdg-desktop-portal kitty quickshell fish nvim mpv \
        "${PROFILE_STOW_PACKAGES[@]}" <<'SCRIPT'
		rm -f "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.bash_logout"
		for pkg in fish kitty quickshell nvim mpv hypr niri xdg-desktop-portal; do
			target="$HOME/.config/$pkg"
			[[ -e "$target" && ! -L "$target" ]] && rm -rf "$target"
		done
		cd "$1" && shift && stow -R -t "$HOME" "$@"
SCRIPT

    local sudoers_tmp=/etc/sudoers.d/99-installer-temp
    printf '%s\n' "$USERNAME ALL=(ALL) NOPASSWD: ALL" >"$sudoers_tmp"
    chmod 440 "$sudoers_tmp"
    trap 'rm -f -- "$sudoers_tmp"' EXIT
    run_as_user <<<'yay -S --needed --noconfirm --removemake --cleanafter antigravity-cli'
    rm -f -- "$sudoers_tmp"
    trap - EXIT

    if [[ -x "$dots/bin/.local/bin/setup-reboot-required" ]]; then
        "$dots/bin/.local/bin/setup-reboot-required" || log_warning "Failed to install reboot-required hook; continuing."
    fi
}

live_main() {
    ((EUID == 0)) || die "Run this script as root from the Arch live ISO."
    [[ -d /sys/firmware/efi/efivars ]] || die "Not booted in UEFI mode. Both machines use systemd-boot."

    if load_install_state || recover_state_from_target; then
        local resume_reply
        read -rp "Resume previous install? [Y/n] " resume_reply </dev/tty
        if [[ "$resume_reply" =~ ^[Nn] ]]; then
            clear_install_state
            NEXT_CHECKPOINT="" SYSTEM_PROFILE="" BOOT_PARTITION="" ROOT_PARTITION=""
        else
            # Older live runs wrote an empty checkpoint to mean "enter chroot".
            [[ -n "$NEXT_CHECKPOINT" ]] || NEXT_CHECKPOINT="${TARGET_STEPS[0]}"
            if in_steps "$NEXT_CHECKPOINT" install_base_system generate_fstab run_target_configuration; then
                ensure_target_mounted || log_warning "Could not remount saved partitions; later steps will retry."
            fi
        fi
    fi

    if in_steps "$NEXT_CHECKPOINT" "${TARGET_STEPS[@]}"; then
        log_info "Resuming target configuration in chroot"
        ensure_target_mounted || die "Failed to mount target filesystems."
        run_target_configuration
    else
        run_resumable_steps "${LIVE_STEPS[@]}"
    fi

    log_success "Installation complete"
    clear_install_state
    printf '\n'
    read -rsn1 -p "Press any key to unmount and reboot (Ctrl+C to cancel)..." </dev/tty
    printf '\n'
    umount -R "$TARGET_ROOT" 2>/dev/null || true
    sleep 2
    reboot
}

target_main() {
    IN_CHROOT=1
    INSTALL_STATE_FILE="/root/install.state"
    load_install_state || die "Missing or invalid chroot installation state"
    in_steps "$NEXT_CHECKPOINT" "${TARGET_STEPS[@]}" || NEXT_CHECKPOINT=""
    run_resumable_steps "${TARGET_STEPS[@]}"
    rm -f /root/install.sh
    clear_install_state
}

# shellcheck disable=SC2218  # self_check intentionally shadows helpers with local test stubs.
self_check() {
    local dir original_state_file original_umask step_log failure_status
    dir=$(mktemp -d)

    assert_profile() {
        SYSTEM_PROFILE=$1
        apply_system_profile
        [[ "$HOSTNAME" == "$2" && "${PROFILE_PACKAGES[*]}" == "$3" && "${PROFILE_EXTRA_PACKAGES[*]}" == "$4" ]]
        [[ "${PROFILE_SERVICES[*]}" == "$5" && "${PROFILE_STOW_PACKAGES[*]}" == "$6" && "$PROFILE_GROUPS" == "$7" ]]
        [[ "$PROFILE_WAYLAND_SESSION" == "$8" && ${#PROFILE_INITRAMFS_MODULES[@]} -eq $9 ]]
    }
    assert_profile wolverine Wolverine "${WOLVERINE_PACKAGES[*]}" "${WOLVERINE_EXTRA_PACKAGES[*]}" nvidia-persistenced hypr "wheel,input,gamemode" hyprland-uwsm.desktop 4
    assert_profile mentalist Mentalist "${MENTALIST_PACKAGES[*]}" "${MENTALIST_EXTRA_PACKAGES[*]}" asusd niri "wheel,input" niri.desktop 0

    local s
    for s in "${LIVE_STEPS[@]}" configure_zram; do
        in_steps "$s" "${TARGET_STEPS[@]}" && die "Unexpected target step: $s"
    done

    original_state_file="$INSTALL_STATE_FILE"
    original_umask=$(umask)
    INSTALL_STATE_FILE="$dir/install.state"
    NEXT_CHECKPOINT=enable_system_services BOOT_PARTITION=/dev/example1 ROOT_PARTITION=/dev/example2
    save_install_state
    [[ "$(umask)" == "$original_umask" && "$(stat -c '%a' "$INSTALL_STATE_FILE")" == 600 ]]
    NEXT_CHECKPOINT="" SYSTEM_PROFILE="" BOOT_PARTITION="" ROOT_PARTITION=""
    load_install_state
    [[ "$NEXT_CHECKPOINT" == enable_system_services && "$SYSTEM_PROFILE" == mentalist ]]
    [[ "$BOOT_PARTITION" == /dev/example1 && "$ROOT_PARTITION" == /dev/example2 ]]

    reject_state() {
        printf '%s\n' "$@" >"$INSTALL_STATE_FILE"
        load_install_state && die "Self-check accepted invalid state"
        return 0
    }
    reject_state enable_system_services unknown /dev/example1 /dev/example2
    [[ "$SYSTEM_PROFILE" == mentalist ]]
    reject_state enable_system_services mentalist /dev/example1
    printf '%s\n' enable_system_services mentalist /dev/example1 /dev/example2 old-layout >"$dir/state-target"
    rm -f "$INSTALL_STATE_FILE"
    ln -s "$dir/state-target" "$INSTALL_STATE_FILE"
    load_install_state && die "Self-check accepted invalid state"
    rm -f "$INSTALL_STATE_FILE"

    step_log="$dir/steps.log"
    _sc1() { printf '%s\n' one >>"$step_log"; }
    _sc2() { printf '%s\n' two >>"$step_log"; }
    _sc3() { printf '%s\n' three >>"$step_log"; }
    _scf() {
        printf '%s\n' fail >>"$step_log"
        return 1
    }
    run_logged() {
        NEXT_CHECKPOINT=$1
        : >"$step_log"
        shift
        run_resumable_steps "$@"
    }

    run_logged "" _sc1 _sc2 _sc3
    [[ "$(<"$step_log")" == $'one\ntwo\nthree' && "$NEXT_CHECKPOINT" == "$INSTALL_COMPLETE_MARKER" ]]
    run_logged _sc2 _sc1 _sc2 _sc3
    [[ "$(<"$step_log")" == $'two\nthree' && "$NEXT_CHECKPOINT" == "$INSTALL_COMPLETE_MARKER" ]]
    run_logged "$INSTALL_COMPLETE_MARKER" _sc1
    [[ ! -s "$step_log" ]]
    run_logged missing_step _sc1 >"$dir/unknown-checkpoint.log" && die "Self-check accepted an unknown checkpoint"
    [[ ! -s "$step_log" ]]

    set +e
    (
        trap - ERR
        set -e
        run_logged "" _sc1 _scf _sc3
    )
    failure_status=$?
    set -e
    ((failure_status != 0))
    [[ "$(<"$step_log")" == $'one\nfail' && "$(head -n1 "$INSTALL_STATE_FILE")" == _scf ]]

    local pacman_fixture="$dir/pacman.conf"
    cat >"$pacman_fixture" <<'EOF'
[options]
#Color
#ParallelDownloads = 5

#[multilib]
#Include = /etc/pacman.d/mirrorlist
EOF
    apply_pacman_defaults "$pacman_fixture"
    cp "$pacman_fixture" "$dir/pacman.expected"
    apply_pacman_defaults "$pacman_fixture"
    cmp -s "$pacman_fixture" "$dir/pacman.expected"
    [[ "$(grep -cE '^(Color|ParallelDownloads = 5|\[multilib\]|Include = /etc/pacman.d/mirrorlist)$' "$pacman_fixture")" == 4 ]]
    [[ "$(grep -c '^ILoveCandy$' "$pacman_fixture")" == 1 ]]
    ensure_pacman_repo "$pacman_fixture" chaotic-aur 'Include = /etc/pacman.d/chaotic-mirrorlist'
    ensure_pacman_repo "$pacman_fixture" chaotic-aur 'Include = /etc/pacman.d/chaotic-mirrorlist'
    [[ "$(grep -c '^\[chaotic-aur\]$' "$pacman_fixture")" == 1 ]]

    install -d "$dir/iwd"
    printf '%s\n' '[Security]' 'Passphrase=secret=value' >"$dir/iwd/Ghuzlan_5G.psk"
    import_iwd_wifi_into_nm "$dir/nm" "$dir/iwd"
    local nm="$dir/nm/Ghuzlan_5G.nmconnection"
    [[ -f "$nm" && "$(stat -c '%a' "$nm")" == 600 ]]
    [[ "$(grep -cE '^(ssid=Ghuzlan_5G|psk=secret=value)$' "$nm")" == 2 ]]
    install -d "$dir/empty-iwd"
    import_iwd_wifi_into_nm "$dir/nm-empty" "$dir/empty-iwd"

    # Bug-1 fix: mirror chroot progress back into the live /run state.
    local mirror_dir="$dir/mirror" mirror_rc mock_checkpoint mock_chroot_rc
    mkdir -p "$mirror_dir/target/root" "$mirror_dir/target/etc/pacman.d" \
        "$mirror_dir/target/etc/NetworkManager/system-connections" "$mirror_dir/run"
    TARGET_ROOT="$mirror_dir/target"
    RUNTIME_SCRIPT="$mirror_dir/install.sh"
    INSTALL_STATE_FILE="$mirror_dir/run/state"
    : >"$RUNTIME_SCRIPT"
    : >"$INSTALL_STATE_FILE"

    ensure_target_mounted() { :; }
    apply_pacman_defaults() { :; }
    import_iwd_wifi_into_nm() { :; }
    arch-chroot() {
        printf '%s\n' "$mock_checkpoint" >"$TARGET_ROOT/root/install.state"
        return "$mock_chroot_rc"
    }
    check_mirror() {
        mock_checkpoint=$1 mock_chroot_rc=$2
        printf '%s\n' stale mentalist /dev/example1 /dev/example2 "$INSTALL_LAYOUT" >"$INSTALL_STATE_FILE"
        set +e
        run_target_configuration
        mirror_rc=$?
        set -e
        [[ "$(head -n1 "$INSTALL_STATE_FILE")" == "$mock_checkpoint" ]]
        ((mock_chroot_rc == 0 ? mirror_rc == 0 : mirror_rc != 0))
    }
    check_mirror enable_system_services 1
    check_mirror bootstrap_user_environment 0

    INSTALL_STATE_FILE="$original_state_file"
    rm -rf -- "$dir"
    log_success "Self-check passed"
}

if [[ "${1:-}" == "chroot" ]]; then
    target_main
elif [[ "${1:-}" == "--self-check" ]]; then
    self_check
else
    live_main
fi
