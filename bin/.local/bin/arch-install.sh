#!/usr/bin/env bash
# =============================================================================
# Arch Linux Custom Installation Script
# Systems: Wolverine (Ryzen 5900X + RTX 3080) | Mentalist (Intel i9 13900H)
# =============================================================================

set -euo pipefail
trap 'echo -e "${RED}[ERROR]${NC} Line $LINENO failed"; exit 1' ERR

# Relocate to /tmp for stability during mount operations
if [[ "$(dirname "$(realpath "$0")" 2>/dev/null)" != "/tmp" && -f "$0" ]]; then
    cp "$0" /tmp/arch-install.sh
    chmod +x /tmp/arch-install.sh
    exec /tmp/arch-install.sh "$@"
fi

# =============================================================================
# COLORS & LOGGING
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${GREEN}=== Step $1: $2 ===${NC}"; }

# =============================================================================
# FIXED CONFIGURATION
# =============================================================================

TIMEZONE="Africa/Cairo"
LOCALE="en_US.UTF-8"
VCONSOLE_KEYMAP="us"
USERNAME="anas"
USER_FULLNAME="Anas Khalifa"
USER_GROUPS="wheel"
WIFI_SSID="Ghuzlan_5G"
MOUNT_POINT="/mnt"

# Derived (set after hostname selection)
declare HOSTNAME
declare IS_PC=false

# Partition selections (set interactively)
declare BOOT_PART ROOT_PART

# PACKAGE ARRAYS - OFFICIAL REPOS (for pacstrap)
# =============================================================================

PKGS_COMMON=(
    # Base
    base base-devel linux linux-firmware networkmanager
    # Shell & CLI
    neovim git bash-completion wget curl fish 7zip bat btop
    cliphist dysk expac eza fastfetch fzf git-filter-repo git-lfs
    inotify-tools just less rsync ripgrep pkgstats pacman-contrib stow
    starship zoxide fd jq tealdeer rustup usbutils wl-clipboard zip
    unrar unzip lshw i2c-tools tokei tree-sitter-cli ffmpegthumbnailer
    # Audio & Accessibility
    pipewire pipewire-jack pipewire-pulse pipewire-alsa wireplumber
    espeak-ng speech-dispatcher
    # System
    bluez plymouth wireless-regdb zram-generator ly mkcert mold gnome-keyring
    xdg-desktop-portal-gnome
    # Desktop Apps
    kitty nautilus nautilus-image-converter
    gnome-calculator gnome-disk-utility gnome-firmware gnome-text-editor
    papers simple-scan qbittorrent kdeconnect mission-center
    # Communication
    telegram-desktop thunderbird
    # Theming
    kvantum qt6ct
    # Media
    mpv mpv-mpris satty
    # Editors
    zed
    # Fonts
    inter-font otf-font-awesome opendesktop-fonts terminus-font gnu-free-fonts
    adobe-source-code-pro-fonts noto-fonts noto-fonts-emoji noto-fonts-extra
    ttf-bitstream-vera ttf-cascadia-code-nerd ttf-fira-code ttf-firacode-nerd
    ttf-liberation ttf-roboto-mono-nerd ttf-scheherazade-new
    tela-circle-icon-theme-dracula
)

PKGS_MENTALIST=(
    # Hardware
    intel-ucode brightnessctl vulkan-intel intel-media-driver acpi_call
    # Niri WM
    niri pipewire-libcamera pipewire-v4l2
    # PHP Stack
    nginx dnsmasq composer php php-fpm php-gd php-igbinary php-imagick
    php-pgsql php-redis php-snmp php-sodium php-sqlite php-xsl mariadb-clients
    # Database
    unixodbc
)

PKGS_WOLVERINE=(
    # Hardware
    amd-ucode nvidia-open nvidia-utils nvidia-settings
    lib32-nvidia-utils libva-nvidia-driver
    # Hyprland WM
    hyprland hyprpicker hyprshot uwsm xdg-desktop-portal-hyprland
    # Gaming
    lib32-gamemode mangohud steam
    # Peripherals
    solaar
)

# =============================================================================
# PACKAGE ARRAYS - AUR/CHAOTIC (for post-chroot pacman)
# =============================================================================

PKGS_AUR_COMMON=(
    # Chaotic-AUR essentials
    chaotic-keyring chaotic-mirrorlist rate-mirrors yay
    # Theming
    bibata-cursor-theme
    # Shell
    fish-autopair fnm
    # Desktop
    nautilus-code-git xdg-terminal-exec-git gpu-screen-recorder-git
    # Communication
    vesktop slack-desktop rustdesk-bin
    # Apps
    zen-browser-bin subliminal-git
    # Fonts
    ttf-material-icons-git ttf-material-symbols-variable-git ttf-ms-fonts
)

PKGS_AUR_MENTALIST=(
    asusctl
)

PKGS_AUR_WOLVERINE=(
    heroic-games-launcher-bin
)

# Auxiliary partition labels to auto-mount
AUX_LABELS=(Work Media Games)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

set_password_with_retry() {
    local target_label="$1"
    shift

    local max_attempts=3
    local attempt=1
    while ((attempt <= max_attempts)); do
        log_info "Set password for $target_label (attempt $attempt/$max_attempts)"
        if "$@"; then
            return 0
        fi
        log_warning "Password setup failed for $target_label."
        attempt=$((attempt + 1))
    done
    log_error "Failed to set password for $target_label after $max_attempts attempts."
    exit 1
}

step_1_detect_host() {
    log_step "1" "Detecting target system"

    local cpu_vendor_raw cpu_vendor="unknown"
    local nvidia_state="unknown"

    cpu_vendor_raw=$(awk -F: '/vendor_id/{print tolower($2); exit}' /proc/cpuinfo | xargs)

    if [[ "$cpu_vendor_raw" == *"authenticamd"* ]]; then
        cpu_vendor="amd"
    elif [[ "$cpu_vendor_raw" == *"genuineintel"* ]]; then
        cpu_vendor="intel"
    fi

    if command -v lspci &>/dev/null; then
        if lspci | grep -Ei 'vga|3d' | grep -qi 'nvidia'; then
            nvidia_state="true"
        else
            nvidia_state="false"
        fi
    fi

    if [[ "$cpu_vendor" == "amd" && "$nvidia_state" == "true" ]]; then
        HOSTNAME="Wolverine"
        IS_PC=true
        log_success "Auto-detected: $HOSTNAME (CPU: $cpu_vendor, NVIDIA: yes)"
        return 0
    fi

    if [[ "$cpu_vendor" == "intel" && "$nvidia_state" == "false" ]]; then
        HOSTNAME="Mentalist"
        IS_PC=false
        log_success "Auto-detected: $HOSTNAME (CPU: $cpu_vendor, NVIDIA: no)"
        return 0
    fi

    log_error "Unsupported hardware combination for this script."
    log_error "Detected CPU vendor: $cpu_vendor"
    log_error "Detected NVIDIA GPU: $nvidia_state"
    log_info "Supported combinations:"
    log_info "  - amd + nvidia => Wolverine"
    log_info "  - intel + no nvidia => Mentalist"
    exit 1
}

menu_select() {
    local prompt="$1"
    local default_idx="$2"
    shift 2
    local options=("$@")
    local selected="$default_idx"
    local key

    printf "%s\n" "$prompt" >/dev/tty
    printf "Use ↑/↓ and Enter.\n" >/dev/tty
    for _ in "${options[@]}"; do
        printf "\n" >/dev/tty
    done

    printf "\033[?25l" >/dev/tty
    while true; do
        printf "\033[%dA" "${#options[@]}" >/dev/tty
        for i in "${!options[@]}"; do
            if ((i == selected)); then
                printf "\r\033[2K  > %s\n" "${options[$i]}" >/dev/tty
            else
                printf "\r\033[2K    %s\n" "${options[$i]}" >/dev/tty
            fi
        done

        IFS= read -rsn1 key </dev/tty
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 key </dev/tty
            case "$key" in
                "[A") selected=$(((selected - 1 + ${#options[@]}) % ${#options[@]})) ;;
                "[B") selected=$(((selected + 1) % ${#options[@]})) ;;
            esac
        elif [[ -z "$key" ]]; then
            break
        fi
    done
    printf "\033[?25h" >/dev/tty
    printf "\n" >/dev/tty
    printf '%s\n' "$selected"
}

run_yay_with_temp_nopasswd() {
    local rule_file="/etc/sudoers.d/90-yay-temp-install"
    local yay_cmd='yay -S --needed --noconfirm --sudoloop --removemake --cleanafter --answerclean None --answerdiff None --answeredit None antigravity quickshell-git'

    printf '%s ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman\n' "$USERNAME" >"$rule_file"
    chmod 0440 "$rule_file"

    if ! visudo -cf "$rule_file" &>/dev/null; then
        log_warning "Temporary sudoers rule validation failed; skipping yay install."
        rm -f "$rule_file"
        return 1
    fi

    local status=0
    runuser -u "$USERNAME" -- bash -lc "$yay_cmd" || status=1
    rm -f "$rule_file"
    return "$status"
}

# =============================================================================
# STEP FUNCTIONS
# =============================================================================

step_2_connectivity() {
    log_step "2" "Checking connectivity"
    local wifi_iface

    if ping -c 1 -W 3 archlinux.org &>/dev/null; then
        log_success "Internet connection available"
        return 0
    fi

    log_warning "No internet connection detected"
    for iface in /sys/class/net/wl*; do
        [[ -e "$iface" ]] && {
            wifi_iface=$(basename "$iface")
            break
        }
    done
    if [[ -z "$wifi_iface" ]]; then
        log_error "No Wi-Fi interface detected."
        exit 1
    fi
    log_info "Using Wi-Fi interface: $wifi_iface"
    log_info "Connecting to Wi-Fi: $WIFI_SSID"

    local wifi_pass
    read -rsp "Enter Wi-Fi passphrase: " wifi_pass
    echo

    iwctl station "$wifi_iface" connect-hidden "$WIFI_SSID" --passphrase "$wifi_pass"
    sleep 5

    if ping -c 1 -W 3 archlinux.org &>/dev/null; then
        log_success "Connected to Wi-Fi"
    else
        log_error "Failed to connect. Please check manually."
        exit 1
    fi
}

step_3_select_partitions() {
    log_step "3" "Partition selection"

    log_info "Detected partitions:"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
    echo

    # Get list of partitions (exclude whole disks, only partitions)
    mapfile -t partitions < <(lsblk -lnpo NAME,SIZE,FSTYPE,LABEL | grep -E "^/dev/(nvme[0-9]+n[0-9]+p|sd[a-z]|vd[a-z])[0-9]")

    if [[ ${#partitions[@]} -eq 0 ]]; then
        log_error "No partitions found!"
        exit 1
    fi

    local default_boot default_root
    default_boot=$(blkid -L BOOT 2>/dev/null || true)
    default_root=$(blkid -L Archlinux 2>/dev/null || true)

    local partition_options=()
    local boot_default_zero=0
    local root_default_zero=0

    for i in "${!partitions[@]}"; do
        local part_dev
        part_dev=$(echo "${partitions[$i]}" | awk '{print $1}')
        local marker=""
        if [[ "$part_dev" == "$default_boot" ]]; then
            marker=" [current BOOT]"
            boot_default_zero=$i
        elif [[ "$part_dev" == "$default_root" ]]; then
            marker=" [current Archlinux]"
            root_default_zero=$i
        fi
        partition_options+=("${partitions[$i]}$marker")
    done

    local boot_selected root_selected

    boot_selected=$(menu_select "Select BOOT partition" "$boot_default_zero" "${partition_options[@]}")
    BOOT_PART=$(echo "${partitions[$boot_selected]}" | awk '{print $1}')

    while true; do
        root_selected=$(menu_select "Select ROOT partition" "$root_default_zero" "${partition_options[@]}")
        ROOT_PART=$(echo "${partitions[$root_selected]}" | awk '{print $1}')
        [[ "$BOOT_PART" != "$ROOT_PART" ]] && break
        log_warning "BOOT and ROOT cannot be the same partition. Please choose again."
    done

    log_success "Selected: BOOT=$BOOT_PART, ROOT=$ROOT_PART"
}

step_4_format_partitions() {
    log_step "4" "Formatting partitions"

    echo
    echo "=============================================="
    echo "           INSTALLATION SUMMARY"
    echo "=============================================="
    echo "Hostname:       $HOSTNAME"
    echo "Boot Partition: $BOOT_PART"
    echo "Root Partition: $ROOT_PART"
    echo "Username:       $USERNAME"
    echo "Timezone:       $TIMEZONE"
    echo "Locale:         $LOCALE"
    $IS_PC && echo "Type:           PC (AMD + NVIDIA)" || echo "Type:           Laptop (Intel)"
    echo "=============================================="
    echo

    log_warning "This will ERASE all data on $BOOT_PART and $ROOT_PART!"
    read -rp "Are you sure you want to continue? [y/N]: " response
    [[ "$response" =~ ^[Yy]$ ]] || {
        log_error "Aborted by user"
        exit 1
    }

    cd / && umount -R "$MOUNT_POINT" 2>/dev/null || true

    log_info "Formatting BOOT partition as FAT32"
    mkfs.fat -F32 -n BOOT "$BOOT_PART"

    log_info "Formatting ROOT partition as ext4"
    mkfs.ext4 -F -L Archlinux "$ROOT_PART"

    log_success "Partitions formatted"
}

step_5_mount() {
    log_step "5" "Mounting filesystems"

    mount -o noatime "$ROOT_PART" "$MOUNT_POINT"
    mkdir -p "$MOUNT_POINT/boot"
    mount "$BOOT_PART" "$MOUNT_POINT/boot"

    log_success "Filesystems mounted"
}

step_6_mirrorlist() {
    log_step "6" "Optimizing mirrors with reflector"

    log_info "Finding fastest mirrors..."
    reflector --country Germany,Austria,Italy,Netherlands,France \
        --latest 20 \
        --protocol https \
        --sort rate \
        --save /etc/pacman.d/mirrorlist \
        --number 12

    pacman -Sy
    log_success "Mirrors optimized"
}

step_7_pacman_defaults() {
    log_step "7" "Configuring pacman defaults (live environment)"

    log_info "Enabling ParallelDownloads, Color, ILoveCandy, multilib"
    sed -i \
        -e 's/^#ParallelDownloads/ParallelDownloads/' \
        -e 's/^#Color/Color/' \
        -e '/\[multilib\]/,/Include/s/^#//' \
        /etc/pacman.conf
    grep -q "^ILoveCandy" /etc/pacman.conf || sed -i '/^Color/a ILoveCandy' /etc/pacman.conf

    log_success "Pacman defaults configured"
}

step_8_pacstrap() {
    log_step "8" "Installing base system"

    local packages=("${PKGS_COMMON[@]}")

    if $IS_PC; then
        packages+=("${PKGS_WOLVERINE[@]}")
    else
        packages+=("${PKGS_MENTALIST[@]}")
    fi

    log_info "Installing ${#packages[@]} packages..."
    pacstrap -K "$MOUNT_POINT" "${packages[@]}"

    log_success "Base system installed"
}

step_9_fstab() {
    log_step "9" "Generating fstab"

    genfstab -L "$MOUNT_POINT" >"$MOUNT_POINT/etc/fstab"

    # Secure boot partition
    sed -i '/\/boot/ s/rw,relatime/rw,relatime,fmask=0077,dmask=0077/' "$MOUNT_POINT/etc/fstab"

    # Auxiliary partitions
    for label in "${AUX_LABELS[@]}"; do
        blkid -L "$label" &>/dev/null || continue
        grep -qE "^[[:space:]]*LABEL=${label}[[:space:]]+" "$MOUNT_POINT/etc/fstab" && {
            log_info "$label already in fstab"
            continue
        }
        log_info "Adding $label partition to fstab"
        echo "LABEL=$label  /mnt/$label  ext4  nosuid,nodev,nofail,x-gvfs-show,x-systemd.makedir,noatime  0 2" \
            >>"$MOUNT_POINT/etc/fstab"
    done

    log_success "fstab generated"
}

step_10_prepare_chroot() {
    log_step "10" "Preparing chroot"

    # Copy the script to chroot (running from /tmp ensures stable source)
    cp /tmp/arch-install.sh "$MOUNT_POINT/root/install.sh"
    chmod +x "$MOUNT_POINT/root/install.sh"

    # Save config for chroot
    cat >"$MOUNT_POINT/root/install.conf" <<EOF
HOSTNAME="$HOSTNAME"
IS_PC=$IS_PC
EOF

    # Copy optimized mirrorlist and pacman.conf from live env
    cp /etc/pacman.d/mirrorlist "$MOUNT_POINT/etc/pacman.d/mirrorlist"
    cp /etc/pacman.conf "$MOUNT_POINT/etc/pacman.conf"
    log_info "Copied mirrorlist and pacman.conf to installed system"

    log_info "Entering chroot..."
    arch-chroot "$MOUNT_POINT" /root/install.sh chroot
}

# =============================================================================
# CHROOT FUNCTIONS
# =============================================================================

chroot_step_11_basics() {
    log_step "11" "System basics"

    log_info "Setting timezone"
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    hwclock --systohc

    log_info "Setting locale"
    sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
    locale-gen
    echo "LANG=$LOCALE" >/etc/locale.conf
    if ! [[ -f /etc/vconsole.conf ]] || ! grep -qE '^[[:space:]]*KEYMAP=' /etc/vconsole.conf; then
        log_warning "/etc/vconsole.conf missing or incomplete. Creating default."
        echo "KEYMAP=$VCONSOLE_KEYMAP" >/etc/vconsole.conf
    fi

    log_info "Setting hostname: $HOSTNAME"
    echo "$HOSTNAME" >/etc/hostname
    cat >/etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

    set_password_with_retry "root" passwd

    log_success "System basics configured"
}

chroot_step_12_bootloader() {
    log_step "12" "Installing bootloader"

    bootctl install

    # Loader config
    cat >/boot/loader/loader.conf <<'EOF'
default arch.conf
timeout 0
console-mode max
editor no
EOF

    # Boot entry
    local kernel_opts="root=LABEL=Archlinux rw quiet splash loglevel=3 nowatchdog"

    cat >/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options $kernel_opts
EOF

    log_success "Bootloader installed"
}

chroot_step_13_repos() {
    log_step "13" "Setting up AUR repos and packages"
    log_info "Appending Chaotic-AUR and Omarchy repos in installed system pacman.conf"

    # Chaotic-AUR
    log_info "Setting up Chaotic-AUR"
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    cat >>/etc/pacman.conf <<EOF

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
    log_info "Added repo [chaotic-aur]"

    # Omarchy
    log_info "Setting up Omarchy"
    cat >>/etc/pacman.conf <<EOF

[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/\$arch
EOF
    log_info "Added repo [omarchy]"

    pacman -Sy

    # Install AUR packages
    log_info "Installing AUR packages..."
    local aur_packages=("${PKGS_AUR_COMMON[@]}")
    if $IS_PC; then
        aur_packages+=("${PKGS_AUR_WOLVERINE[@]}")
    else
        aur_packages+=("${PKGS_AUR_MENTALIST[@]}")
    fi

    pacman -S --noconfirm "${aur_packages[@]}"

    log_success "AUR packages installed"
}

chroot_step_14_zram() {
    log_step "14" "Configuring ZRAM"

    cat >/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
EOF

    cat >/etc/sysctl.d/99-zram.conf <<'EOF'
vm.swappiness = 180
EOF

    log_success "ZRAM configured"
}

chroot_step_15_initramfs() {
    log_step "15" "Configuring initramfs"

    if $IS_PC; then
        log_info "Adding NVIDIA modules"
        sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    fi
    sed -i 's/^HOOKS=.*/HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)/' /etc/mkinitcpio.conf

    mkinitcpio -P

    log_success "Initramfs regenerated"
}

chroot_step_16_services() {
    log_step "16" "Enabling services"

    local services=(
        NetworkManager
        systemd-timesyncd
        fstrim.timer
        bluetooth
        ly@tty2
        power-profiles-daemon
        fwupd-refresh.timer
    )

    if $IS_PC; then
        services+=(nvidia-persistenced)
    fi

    for svc in "${services[@]}"; do
        log_info "Enabling $svc"
        systemctl enable "$svc" 2>/dev/null || true
    done

    # Ly configuration
    log_info "Configuring Ly"
    sed -i \
        -e 's/^animation = none/animation = matrix/' \
        -e 's/^bigclock = none/bigclock = en/' \
        -e 's/^clock = .*/clock = %c/' \
        /etc/ly/config.ini 2>/dev/null || true

    log_success "Services enabled"
}

chroot_step_17_user() {
    log_step "17" "Creating user"

    log_info "Creating user: $USERNAME"
    useradd -m -c "$USER_FULLNAME" -G "$USER_GROUPS" -s /usr/bin/fish "$USERNAME"

    set_password_with_retry "$USERNAME" passwd "$USERNAME"

    log_info "Enabling sudo for wheel group"
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    log_success "User created"
}

chroot_step_18_post_user() {
    log_step "18" "Post-install user bootstrap"

    local dots_dir="/mnt/Work/Dots"
    local backup_script="$dots_dir/bin/.local/bin/backup-home"
    local stow_packages=(bin kitty quickshell fish nvim mpv wezterm)

    if $IS_PC; then
        stow_packages+=(hypr)
    else
        stow_packages+=(niri)
    fi

    # Mount Work partition
    local work_device
    work_device=$(blkid -L Work 2>/dev/null || true)
    if [[ -z "$work_device" ]]; then
        log_warning "Partition label Work not found. Skipping post-user setup."
        return 0
    fi
    mkdir -p /mnt/Work
    umount /mnt/Work 2>/dev/null || true
    if ! mount "$work_device" /mnt/Work; then
        log_warning "Failed to mount Work partition. Skipping post-user setup."
        return 0
    fi

    if [[ ! -d "$dots_dir" ]]; then
        log_warning "Dots directory not found at $dots_dir. Skipping restore/stow/gsettings."
        return 0
    fi

    if ! runuser -u "$USERNAME" -- bash -lc "\"$backup_script\" -r"; then
        log_warning "backup-home restore failed (or script missing); continuing."
    fi

    if ! runuser -u "$USERNAME" -- bash -lc 'rm -f "$HOME/.bashrc" "$HOME/.bash_profile"'; then
        log_warning "Failed removing default bash files; continuing."
    fi

    if ! runuser -u "$USERNAME" -- bash -lc "cd '$dots_dir' && stow -t \"\$HOME\" ${stow_packages[*]}"; then
        log_warning "Stow failed; continuing."
    fi

    if ! run_yay_with_temp_nopasswd; then
        log_warning "yay install failed for antigravity/quickshell-git; continuing."
    fi

    if ! runuser -u "$USERNAME" -- bash -lc "dbus-run-session -- gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'"; then
        log_warning "Failed to set gsettings dark preference; continuing."
    fi

    log_success "Post-user bootstrap complete"
}

chroot_step_19_cleanup() {
    log_step "19" "Cleanup"

    rm -f /root/install.sh /root/install.conf
    rm -f /etc/sudoers.d/90-yay-temp-install

    echo
    log_success "Installation complete!"
    echo
    echo "Next steps:"
    echo "  1. Unmount: umount -R /mnt"
    echo "  2. Reboot: reboot"
    echo
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo
    echo "========================================"
    echo "   Arch Linux Installation Script"
    echo "========================================"
    echo

    step_1_detect_host
    step_2_connectivity
    step_3_select_partitions
    step_4_format_partitions
    step_5_mount
    step_6_mirrorlist
    step_7_pacman_defaults
    step_8_pacstrap
    step_9_fstab
    step_10_prepare_chroot
}

chroot_main() {
    # Load config
    source /root/install.conf

    chroot_step_11_basics
    chroot_step_12_bootloader
    chroot_step_13_repos
    chroot_step_14_zram
    chroot_step_15_initramfs
    chroot_step_16_services
    chroot_step_17_user
    chroot_step_18_post_user
    chroot_step_19_cleanup
}

if [[ "${1:-}" == "chroot" ]]; then
    chroot_main
else
    main
fi
