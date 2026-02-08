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
VCONSOLE_KEYMAP="us"
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

check_internet() {
    ping -c 1 -W 3 archlinux.org &>/dev/null
}

get_wifi_interface() {
    local iface_path
    local iface_name=""

    if command -v iw &>/dev/null; then
        iface_name=$(iw dev 2>/dev/null | awk '$1 == "Interface" { print $2; exit }')
        if [[ -n "$iface_name" ]]; then
            echo "$iface_name"
            return 0
        fi
    fi

    for iface_path in /sys/class/net/wl*; do
        [[ -e "$iface_path" ]] || continue
        basename "$iface_path"
        return 0
    done
}

confirm() {
    local prompt="${1:-Continue?}"
    read -rp "$prompt [y/N]: " response
    [[ "$response" =~ ^[Yy]$ ]]
}

require_root() {
    if ((EUID != 0)); then
        log_error "This script must run as root."
        log_info "Try: sudo -i"
        exit 1
    fi
}

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

append_repo_if_missing() {
    local repo_name="$1"
    local repo_block="$2"

    if grep -qE "^[[:space:]]*\\[$repo_name\\][[:space:]]*$" /etc/pacman.conf; then
        log_info "Repo [$repo_name] already configured, skipping"
        return 0
    fi

    printf '\n%s\n' "$repo_block" >>/etc/pacman.conf
    log_info "Added repo [$repo_name]"
}

detect_host_strict() {
    log_step "0.5" "Detecting target system"

    local cpu_vendor_raw="" cpu_vendor="unknown"
    local nvidia_state="unknown"

    if command -v lscpu &>/dev/null; then
        cpu_vendor_raw=$(lscpu 2>/dev/null | awk -F: '/Vendor ID/{print tolower($2)}' | xargs)
    fi
    if [[ -z "$cpu_vendor_raw" && -r /proc/cpuinfo ]]; then
        cpu_vendor_raw=$(awk -F: '/vendor_id/{print tolower($2); exit}' /proc/cpuinfo | xargs)
    fi

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

    if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
        log_warning "Interactive menu unavailable, using numbered input" >&2
        echo "$prompt" >&2
        for i in "${!options[@]}"; do
            echo "  $((i + 1))) ${options[$i]}" >&2
        done
        while true; do
            read -rp "Select [1-${#options[@]}]: " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
                printf '%s\n' "$((choice - 1))"
                return 0
            fi
            echo "Invalid selection" >&2
        done
    fi

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

ensure_vconsole_conf() {
    if [[ -f /etc/vconsole.conf ]] && grep -qE '^[[:space:]]*KEYMAP=' /etc/vconsole.conf; then
        return 0
    fi

    log_warning "/etc/vconsole.conf missing or incomplete. Creating default config."
    cat >/etc/vconsole.conf <<EOF
KEYMAP=$VCONSOLE_KEYMAP
EOF
}

configure_pacman_defaults() {
    local conf="${1:-/etc/pacman.conf}"

    log_info "Enabling ParallelDownloads, Color, ILoveCandy in $conf"
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' "$conf"
    sed -i 's/^#Color/Color/' "$conf"
    grep -q "^ILoveCandy" "$conf" || sed -i '/^Color/a ILoveCandy' "$conf"

    log_info "Enabling multilib in $conf"
    sed -i '/\[multilib\]/,/Include/s/^#//' "$conf"
}

mount_work_partition() {
    local work_mount="/mnt/Work"
    local work_device mounted_source work_real mounted_real

    mkdir -p "$work_mount"

    work_device=$(blkid -L Work 2>/dev/null || true)
    if [[ -z "$work_device" ]]; then
        log_warning "Partition label Work not found. Skipping post-user bootstrap."
        return 1
    fi
    work_real=$(readlink -f "$work_device" 2>/dev/null || echo "$work_device")

    if findmnt -rn -M "$work_mount" >/dev/null 2>&1; then
        mounted_source=$(findmnt -rn -o SOURCE -M "$work_mount" 2>/dev/null || true)
        mounted_real=$(readlink -f "$mounted_source" 2>/dev/null || echo "$mounted_source")
        if [[ "$mounted_real" == "$work_real" ]]; then
            return 0
        fi
        log_warning "$work_mount is mounted from $mounted_source, expected $work_device. Skipping post-user bootstrap."
        return 1
    fi

    if ! mount "$work_device" "$work_mount"; then
        log_warning "Failed to mount Work partition at $work_mount. Skipping post-user bootstrap."
        return 1
    fi
}

run_as_user() {
    local cmd="$1"
    runuser -u "$USERNAME" -- bash -lc "$cmd"
}

run_yay_with_temp_nopasswd() {
    local rule_file="/etc/sudoers.d/90-yay-temp-install"
    local yay_cmd='yay -S --needed --noconfirm --sudoloop --removemake --cleanafter --answerclean None --answerdiff None --answeredit None antigravity quickshell-git'
    local status=0

    printf '%s ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman\n' "$USERNAME" >"$rule_file"
    chmod 0440 "$rule_file"

    if command -v visudo &>/dev/null; then
        if ! visudo -cf "$rule_file" >/dev/null 2>&1; then
            log_warning "Temporary sudoers rule validation failed; skipping yay install."
            status=1
        fi
    fi

    if ((status == 0)) && ! run_as_user "$yay_cmd"; then
        status=1
    fi

    rm -f "$rule_file"
    return "$status"
}

# =============================================================================
# STEP FUNCTIONS
# =============================================================================

step_0_connectivity() {
    log_step "0" "Checking connectivity"
    local wifi_iface

    if check_internet; then
        log_success "Internet connection available"
        return 0
    fi

    log_warning "No internet connection detected"
    wifi_iface=$(get_wifi_interface)
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

    if check_internet; then
        log_success "Connected to Wi-Fi"
    else
        log_error "Failed to connect. Please check manually."
        exit 1
    fi
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
    default_boot=$(blkid -L BOOT 2>/dev/null || true)
    default_root=$(blkid -L Archlinux 2>/dev/null || true)

    local partition_options=()
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
        partition_options+=("${partitions[$i]}$marker")
    done

    local boot_selected root_selected
    local boot_default_zero=0
    local root_default_zero=0
    [[ -n "$default_boot_idx" ]] && boot_default_zero=$((default_boot_idx - 1))
    [[ -n "$default_root_idx" ]] && root_default_zero=$((default_root_idx - 1))

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

cleanup_mounts_before_format() {
    cd /
    umount -R "$MOUNT_POINT" 2>/dev/null || true
    umount "$BOOT_PART" 2>/dev/null || true
    umount "$ROOT_PART" 2>/dev/null || true

    if findmnt -rn -S "$BOOT_PART" >/dev/null 2>&1; then
        log_error "$BOOT_PART is still mounted."
        exit 1
    fi
    if findmnt -rn -S "$ROOT_PART" >/dev/null 2>&1; then
        log_error "$ROOT_PART is still mounted."
        exit 1
    fi
    if findmnt -Rno TARGET "$MOUNT_POINT" >/dev/null 2>&1; then
        log_error "Some mounts under $MOUNT_POINT are still active:"
        findmnt -Rno TARGET,SOURCE,FSTYPE "$MOUNT_POINT"
        exit 1
    fi
}

step_2_format_partitions() {
    log_step "2.5" "Formatting partitions"

    show_summary

    log_warning "This will ERASE all data on $BOOT_PART and $ROOT_PART!"
    if ! confirm "Are you sure you want to continue?"; then
        log_error "Aborted by user"
        exit 1
    fi

    cleanup_mounts_before_format

    log_info "Formatting BOOT partition as FAT32"
    mkfs.fat -F32 -n BOOT "$BOOT_PART"

    log_info "Formatting ROOT partition as ext4"
    mkfs.ext4 -F -L Archlinux "$ROOT_PART"

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
    reflector --country Germany,Austria,Italy,Netherlands,France \
        --latest 20 \
        --protocol https \
        --sort rate \
        --save /etc/pacman.d/mirrorlist \
        --number 12

    pacman -Sy
    log_success "Mirrors optimized"
}

step_4_5_pacman_defaults_live() {
    log_step "4.5" "Configuring pacman defaults (live environment)"
    configure_pacman_defaults /etc/pacman.conf
    log_success "Pacman defaults configured in live environment"
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

    genfstab -L "$MOUNT_POINT" >"$MOUNT_POINT/etc/fstab"

    # Secure boot partition
    sed -i '/\/boot/ s/rw,relatime/rw,relatime,fmask=0077,dmask=0077/' "$MOUNT_POINT/etc/fstab"

    # Auxiliary partitions
    for label in "${AUX_LABELS[@]}"; do
        if blkid -L "$label" &>/dev/null; then
            if grep -qE "^[[:space:]]*LABEL=${label}[[:space:]]+" "$MOUNT_POINT/etc/fstab"; then
                log_info "$label already exists in fstab, skipping"
                continue
            fi
            log_info "Adding $label partition to fstab"
            echo "LABEL=$label  /mnt/$label  ext4  nosuid,nodev,nofail,x-gvfs-show,x-systemd.makedir,noatime  0 2" \
                >>"$MOUNT_POINT/etc/fstab"
        fi
    done

    log_success "fstab generated"
}

write_chroot_script() {
    local target="$1"

    {
        cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
        printf "RED=%q\nGREEN=%q\nYELLOW=%q\nBLUE=%q\nNC=%q\n" \
            "$RED" "$GREEN" "$YELLOW" "$BLUE" "$NC"
        echo "trap 'echo -e \"\${RED}[ERROR]\${NC} Line \$LINENO failed\"; exit 1' ERR"
        printf "TIMEZONE=%q\nLOCALE=%q\nVCONSOLE_KEYMAP=%q\nUSERNAME=%q\nUSER_FULLNAME=%q\nUSER_GROUPS=%q\n" \
            "$TIMEZONE" "$LOCALE" "$VCONSOLE_KEYMAP" "$USERNAME" "$USER_FULLNAME" "$USER_GROUPS"
        declare -p PKGS_AUR_COMMON PKGS_AUR_MENTALIST PKGS_AUR_WOLVERINE
        declare -f log_info log_success log_warning log_error log_step
        declare -f require_root set_password_with_retry append_repo_if_missing ensure_vconsole_conf configure_pacman_defaults
        declare -f mount_work_partition run_as_user run_yay_with_temp_nopasswd
        declare -f chroot_step_8_basics chroot_step_9_bootloader chroot_step_10_repos
        declare -f chroot_step_11_zram chroot_step_12_initramfs chroot_step_13_services
        declare -f chroot_step_14_user chroot_step_14_post_user_setup chroot_step_15_cleanup chroot_main
        cat <<'EOF'
if [[ "${1:-}" == "chroot" ]]; then
    chroot_main
fi
EOF
    } >"$target"

    chmod +x "$target"
}

step_7_prepare_chroot() {
    log_step "7" "Preparing chroot"

    # Build a standalone chroot script (works for local file and process substitution runs).
    write_chroot_script "$MOUNT_POINT/root/install.sh"

    # Save config for chroot
    cat >"$MOUNT_POINT/root/install.conf" <<EOF
HOSTNAME="$HOSTNAME"
IS_PC=$IS_PC
EOF

    # Copy optimized mirrorlist from live env
    cp /etc/pacman.d/mirrorlist "$MOUNT_POINT/etc/pacman.d/mirrorlist"
    log_info "Copied live mirrorlist to installed system"

    # Copy pacman defaults configured in live env
    cp /etc/pacman.conf "$MOUNT_POINT/etc/pacman.conf"
    log_info "Copied live pacman.conf to installed system"

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
    ensure_vconsole_conf

    log_info "Setting hostname: $HOSTNAME"
    echo "$HOSTNAME" >/etc/hostname
    cat >/etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

    set_password_with_retry "root" passwd

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
    local kernel_opts="root=LABEL=Archlinux rw quiet splash loglevel=3 nowatchdog"

    cat >/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options $kernel_opts
EOF

    log_success "Bootloader installed"
}

chroot_step_10_repos() {
    log_step "10" "Setting up AUR repos and packages"
    log_info "Appending Chaotic-AUR and Omarchy repos in installed system pacman.conf"

    # Chaotic-AUR
    log_info "Setting up Chaotic-AUR"
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    append_repo_if_missing "chaotic-aur" "[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist"

    # Omarchy
    log_info "Setting up Omarchy"
    append_repo_if_missing "omarchy" "[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/\$arch"

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
    sed -i 's/^animation = none/animation = matrix/' /etc/ly/config.ini 2>/dev/null || true
    sed -i 's/^bigclock = none/bigclock = en/' /etc/ly/config.ini 2>/dev/null || true
    sed -i 's/^clock = .*/clock = %c/' /etc/ly/config.ini 2>/dev/null || true

    log_success "Services enabled"
}

chroot_step_14_user() {
    log_step "14" "Creating user"

    log_info "Creating user: $USERNAME"
    useradd -m -c "$USER_FULLNAME" -G "$USER_GROUPS" -s /usr/bin/fish "$USERNAME"

    set_password_with_retry "$USERNAME" passwd "$USERNAME"

    log_info "Enabling sudo for wheel group"
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    log_success "User created"
}

chroot_step_14_post_user_setup() {
    log_step "14.5" "Post-install user bootstrap"

    local dots_dir="/mnt/Work/Dots"
    local backup_script="$dots_dir/bin/.local/bin/backup-home"
    local stow_packages=(bin kitty quickshell fish nvim mpv wezterm)
    local stow_cmd

    if $IS_PC; then
        stow_packages+=(hypr)
    else
        stow_packages+=(niri)
    fi

    if ! mount_work_partition; then
        return 0
    fi

    if [[ ! -d "$dots_dir" ]]; then
        log_warning "Dots directory not found at $dots_dir. Skipping restore/stow/gsettings."
        return 0
    fi

    if ! run_as_user "\"$backup_script\" -r"; then
        log_warning "backup-home restore failed (or script missing); continuing."
    fi

    if ! run_as_user 'rm -f "$HOME/.bashrc" "$HOME/.bash_profile"'; then
        log_warning "Failed removing default bash files; continuing."
    fi

    stow_cmd=$(printf 'cd %q && stow -t "$HOME"' "$dots_dir")
    for pkg in "${stow_packages[@]}"; do
        stow_cmd+=" $(printf '%q' "$pkg")"
    done
    if ! run_as_user "$stow_cmd"; then
        log_warning "Stow failed; continuing."
    fi

    if ! run_yay_with_temp_nopasswd; then
        log_warning "yay install failed for antigravity/quickshell-git; continuing."
    fi

    if ! run_as_user "dbus-run-session -- gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'"; then
        log_warning "Failed to set gsettings dark preference; continuing."
    fi

    log_success "Post-user bootstrap complete"
}

chroot_step_15_cleanup() {
    log_step "15" "Cleanup"

    rm -f /root/install.sh /root/install.conf
    rm -f /etc/sudoers.d/90-yay-temp-install

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
    require_root
    echo
    echo "========================================"
    echo "   Arch Linux Installation Script"
    echo "========================================"
    echo

    detect_host_strict
    step_0_connectivity
    step_2_select_partitions
    step_2_format_partitions
    step_3_mount
    step_4_mirrorlist
    step_4_5_pacman_defaults_live
    step_5_pacstrap
    step_6_fstab
    step_7_prepare_chroot
}

chroot_main() {
    require_root
    # Load config
    source /root/install.conf

    chroot_step_8_basics
    chroot_step_9_bootloader
    chroot_step_10_repos
    chroot_step_11_zram
    chroot_step_12_initramfs
    chroot_step_13_services
    chroot_step_14_user
    chroot_step_14_post_user_setup
    chroot_step_15_cleanup
}

# Entry point
if [[ "${1:-}" == "chroot" ]]; then
    chroot_main
else
    main
fi
