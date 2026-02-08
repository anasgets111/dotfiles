#!/usr/bin/env bash
# =============================================================================
# Arch Linux Custom Installation Script
# Systems: Wolverine (Ryzen 5900X + RTX 3080) | Mentalist (Intel i9 13900H)
# =============================================================================

set -euo pipefail
trap 'echo -e "${RED}[ERROR]${NC} Line $LINENO failed"; exit 1' ERR

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
USERNAME="anas"
USER_FULLNAME="Anas Khalifa"
USER_GROUPS="wheel,audio,video,network,storage"
WIFI_SSID="Ghuzlan_5G"
MOUNT_POINT="/mnt"

# Derived (set after hostname selection)
HOSTNAME=""
IS_PC=false

# Partition selections (set interactively)
BOOT_PART=""
ROOT_PART=""

# =============================================================================
# PACKAGE ARRAYS
# =============================================================================
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
    amd-ucode nvidia-open nvidia-utils nvidia-settings vulkan-nvidia
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

check_internet() {
    ping -c 1 -W 3 archlinux.org &>/dev/null
}

confirm() {
    local prompt="${1:-Continue?}"
    read -rp "$prompt [y/N]: " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# =============================================================================
# STEP FUNCTIONS
# =============================================================================

step_0_connectivity() {
    log_step "0" "Checking connectivity"

    if check_internet; then
        log_success "Internet connection available"
        return 0
    fi

    log_warning "No internet connection detected"
    log_info "Connecting to Wi-Fi: $WIFI_SSID"

    read -rsp "Enter Wi-Fi passphrase: " wifi_pass
    echo

    iwctl station wlan0 connect-hidden "$WIFI_SSID" --passphrase "$wifi_pass"
    sleep 5

    if check_internet; then
        log_success "Connected to Wi-Fi"
    else
        log_error "Failed to connect. Please check manually."
        exit 1
    fi
}

select_hostname() {
    log_step "0.5" "Select target system"

    echo "1) Mentalist (Intel i9 13900H Laptop)"
    echo "2) Wolverine (Ryzen 5900X + RTX 3080 PC)"
    echo

    while true; do
        read -rp "Select [1/2]: " choice
        case $choice in
        1)
            HOSTNAME="Mentalist"
            IS_PC=false
            break
            ;;
        2)
            HOSTNAME="Wolverine"
            IS_PC=true
            break
            ;;
        *) echo "Invalid choice" ;;
        esac
    done

    log_success "Selected: $HOSTNAME"
}

step_1_configure_pacman() {
    log_step "1" "Configuring pacman"

    log_info "Enabling ParallelDownloads, Color, ILoveCandy"
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    grep -q "^ILoveCandy" /etc/pacman.conf || sed -i '/^Color/a ILoveCandy' /etc/pacman.conf

    log_info "Enabling multilib"
    sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf

    log_success "Pacman configured"
}

step_2_select_partitions() {
    log_step "2" "Partition selection"

    log_info "Detected partitions:"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
    echo

    # Get list of partitions (exclude whole disks, only partitions)
    mapfile -t partitions < <(lsblk -lnpo NAME,SIZE,FSTYPE,LABEL | grep -E "^/dev/(nvme[0-9]+n[0-9]+p|sd[a-z]|vd[a-z])[0-9]")

    if [[ ${#partitions[@]} -eq 0 ]]; then
        log_error "No partitions found!"
        exit 1
    fi

    # Find defaults by label
    local default_boot_idx="" default_root_idx=""
    local default_boot default_root
    default_boot=$(blkid -L BOOT 2>/dev/null || echo "")
    default_root=$(blkid -L Archlinux 2>/dev/null || echo "")

    echo "Available partitions:"
    for i in "${!partitions[@]}"; do
        local part_dev
        part_dev=$(echo "${partitions[$i]}" | awk '{print $1}')
        local marker=""
        if [[ "$part_dev" == "$default_boot" ]]; then
            marker=" [current BOOT]"
            default_boot_idx=$((i + 1))
        elif [[ "$part_dev" == "$default_root" ]]; then
            marker=" [current Archlinux]"
            default_root_idx=$((i + 1))
        fi
        echo "  $((i + 1))) ${partitions[$i]}$marker"
    done
    echo

    # Select BOOT partition
    local boot_prompt="Select BOOT partition"
    [[ -n "$default_boot_idx" ]] && boot_prompt="$boot_prompt [$default_boot_idx]"
    while true; do
        read -rp "$boot_prompt: " boot_choice
        boot_choice="${boot_choice:-$default_boot_idx}"
        if [[ "$boot_choice" =~ ^[0-9]+$ ]] && ((boot_choice >= 1 && boot_choice <= ${#partitions[@]})); then
            BOOT_PART=$(echo "${partitions[$((boot_choice - 1))]}" | awk '{print $1}')
            break
        fi
        echo "Invalid selection. Enter a number 1-${#partitions[@]}"
    done

    # Select ROOT partition
    local root_prompt="Select ROOT partition"
    [[ -n "$default_root_idx" ]] && root_prompt="$root_prompt [$default_root_idx]"
    while true; do
        read -rp "$root_prompt: " root_choice
        root_choice="${root_choice:-$default_root_idx}"
        if [[ "$root_choice" =~ ^[0-9]+$ ]] && ((root_choice >= 1 && root_choice <= ${#partitions[@]})); then
            ROOT_PART=$(echo "${partitions[$((root_choice - 1))]}" | awk '{print $1}')
            break
        fi
        echo "Invalid selection. Enter a number 1-${#partitions[@]}"
    done

    # Validate not same partition
    if [[ "$BOOT_PART" == "$ROOT_PART" ]]; then
        log_error "BOOT and ROOT cannot be the same partition!"
        exit 1
    fi

    log_success "Selected: BOOT=$BOOT_PART, ROOT=$ROOT_PART"
}

show_summary() {
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
    if $IS_PC; then
        echo "Type:           PC (AMD + NVIDIA)"
    else
        echo "Type:           Laptop (Intel)"
    fi
    echo "=============================================="
    echo
}

step_2_format_partitions() {
    log_step "2.5" "Formatting partitions"

    show_summary

    log_warning "This will ERASE all data on $BOOT_PART and $ROOT_PART!"
    if ! confirm "Are you sure you want to continue?"; then
        log_error "Aborted by user"
        exit 1
    fi

    log_info "Formatting BOOT partition as FAT32"
    mkfs.fat -F32 -n BOOT "$BOOT_PART"

    log_info "Formatting ROOT partition as ext4"
    mkfs.ext4 -L Archlinux "$ROOT_PART"

    log_success "Partitions formatted"
}

step_3_mount() {
    log_step "3" "Mounting filesystems"

    mount -o noatime "$ROOT_PART" "$MOUNT_POINT"
    mkdir -p "$MOUNT_POINT/boot"
    mount "$BOOT_PART" "$MOUNT_POINT/boot"

    log_success "Filesystems mounted"
}

step_4_mirrorlist() {
    log_step "4" "Optimizing mirrors with reflector"

    log_info "Finding fastest mirrors..."
    reflector --country Germany,Austria,Italy,Netherlands,France --protocol https --age 12 --sort rate --save /etc/pacman.d/mirrorlist

    pacman -Sy
    log_success "Mirrors optimized"
}

step_5_pacstrap() {
    log_step "5" "Installing base system"

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

step_6_fstab() {
    log_step "6" "Generating fstab"

    genfstab -U "$MOUNT_POINT" >>"$MOUNT_POINT/etc/fstab"

    # Secure boot partition
    sed -i '/\/boot/ s/rw,relatime/rw,relatime,fmask=0077,dmask=0077/' "$MOUNT_POINT/etc/fstab"

    # Auxiliary partitions
    for label in "${AUX_LABELS[@]}"; do
        if blkid -L "$label" &>/dev/null; then
            log_info "Adding $label partition to fstab"
            echo "LABEL=$label  /mnt/$label  ext4  nosuid,nodev,nofail,x-gvfs-show,x-systemd.makedir,noatime  0 2" \
                >>"$MOUNT_POINT/etc/fstab"
        fi
    done

    log_success "fstab generated"
}

step_7_prepare_chroot() {
    log_step "7" "Preparing chroot"

    # Copy this script to chroot
    cp "$0" "$MOUNT_POINT/root/install.sh"
    chmod +x "$MOUNT_POINT/root/install.sh"

    # Save config for chroot
    cat >"$MOUNT_POINT/root/install.conf" <<EOF
HOSTNAME="$HOSTNAME"
IS_PC=$IS_PC
EOF

    # Copy optimized mirrorlist from live env
    cp /etc/pacman.d/mirrorlist "$MOUNT_POINT/etc/pacman.d/mirrorlist"

    log_info "Entering chroot..."
    arch-chroot "$MOUNT_POINT" /root/install.sh chroot
}

# =============================================================================
# CHROOT FUNCTIONS
# =============================================================================

chroot_step_8_basics() {
    log_step "8" "System basics"

    log_info "Setting timezone"
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    hwclock --systohc

    log_info "Setting locale"
    sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
    locale-gen
    echo "LANG=$LOCALE" >/etc/locale.conf

    log_info "Setting hostname: $HOSTNAME"
    echo "$HOSTNAME" >/etc/hostname
    cat >/etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

    log_info "Set root password"
    passwd

    log_success "System basics configured"
}

chroot_step_9_bootloader() {
    log_step "9" "Installing bootloader"

    bootctl install

    # Loader config
    cat >/boot/loader/loader.conf <<'EOF'
default arch.conf
timeout 0
console-mode max
editor no
EOF

    # Boot entry
    local options="root=LABEL=Archlinux rw quiet splash loglevel=3 nowatchdog"

    cat >/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options $options
EOF

    log_success "Bootloader installed"
}

chroot_step_10_repos() {
    log_step "10" "Setting up AUR repos and packages"

    # Chaotic-AUR
    log_info "Setting up Chaotic-AUR"
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    cat >>/etc/pacman.conf <<'EOF'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

    # Omarchy
    log_info "Setting up Omarchy"
    cat >>/etc/pacman.conf <<'EOF'

[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/$arch
EOF

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

chroot_step_11_zram() {
    log_step "11" "Configuring ZRAM"

    cat >/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
EOF

    cat >/etc/sysctl.d/99-zram.conf <<'EOF'
vm.swappiness = 180
EOF

    log_success "ZRAM configured"
}

chroot_step_12_initramfs() {
    log_step "12" "Configuring initramfs"

    if $IS_PC; then
        log_info "Adding NVIDIA modules"
        sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        sed -i 's/^HOOKS=.*/HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)/' /etc/mkinitcpio.conf
    else
        sed -i 's/^HOOKS=.*/HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard keymap sd-vconsole block filesystems fsck)/' /etc/mkinitcpio.conf
    fi

    mkinitcpio -P

    log_success "Initramfs regenerated"
}

chroot_step_13_services() {
    log_step "13" "Enabling services"

    local services=(
        NetworkManager
        systemd-timesyncd
        fstrim.timer
        bluetooth
        ly
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
    sed -i 's/^animation = none/animation = matrix/' /etc/ly/config.ini 2>/dev/null || true
    sed -i 's/^bigclock = none/bigclock = en/' /etc/ly/config.ini 2>/dev/null || true
    sed -i 's/^clock = .*/clock = %c/' /etc/ly/config.ini 2>/dev/null || true

    log_success "Services enabled"
}

chroot_step_14_user() {
    log_step "14" "Creating user"

    log_info "Creating user: $USERNAME"
    useradd -m -c "$USER_FULLNAME" -G "$USER_GROUPS" -s /usr/bin/fish "$USERNAME"

    log_info "Set password for $USERNAME"
    passwd "$USERNAME"

    log_info "Enabling sudo for wheel group"
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    log_success "User created"
}

chroot_step_15_cleanup() {
    log_step "15" "Cleanup"

    rm -f /root/install.sh /root/install.conf

    echo
    log_success "Installation complete!"
    echo
    echo "Next steps:"
    echo "  1. Exit chroot: exit"
    echo "  2. Unmount: umount -R /mnt"
    echo "  3. Reboot: reboot"
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

    select_hostname
    step_0_connectivity
    step_1_configure_pacman
    step_2_select_partitions
    step_2_format_partitions
    step_3_mount
    step_4_mirrorlist
    step_5_pacstrap
    step_6_fstab
    step_7_prepare_chroot
}

chroot_main() {
    # Load config
    source /root/install.conf

    chroot_step_8_basics
    chroot_step_9_bootloader
    chroot_step_10_repos
    chroot_step_11_zram
    chroot_step_12_initramfs
    chroot_step_13_services
    chroot_step_14_user
    chroot_step_15_cleanup
}

# Entry point
if [[ "${1:-}" == "chroot" ]]; then
    chroot_main
else
    main
fi
