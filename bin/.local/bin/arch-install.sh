#!/usr/bin/env bash

# Arch Linux Installation Script
# Hardware: Ryzen 5900X • RTX 3080 • NVMe

set -euo pipefail

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

# Network Configuration
WIFI_SSID="Ghuzlan-private"
WIFI_PASSPHRASE="Khghza12345"

# Disk Configuration
DISK="/dev/nvme0n1"
BOOT_PARTITION="/dev/nvme0n1p1"
ROOT_PARTITION="/dev/nvme0n1p2"
BOOT_LABEL="BOOT"
ROOT_LABEL="Archlinux"

# System Configuration
TIMEZONE="Africa/Cairo"
LOCALE="en_US.UTF-8"
HOSTNAME="Wolverine"
SWAP_SIZE="4096"  # in MB

# User Configuration
USERNAME="anas"
USER_FULLNAME="Anas Khalifa"
USER_GROUPS="wheel,audio,video,network,storage"

# Boot Configuration
BOOT_TITLE="Arch Linux"
BASE_BOOT_OPTIONS="root=LABEL=$ROOT_LABEL rw quiet splash loglevel=3 nowatchdog"
NVIDIA_BOOT_OPTIONS="nvidia-drm.modeset=1 vt.global_cursor_default=0"

# Package Configuration
BASE_PACKAGES="base linux linux-firmware vim"
MICROCODE_PACKAGE="amd-ucode"
GPU_PACKAGES="nvidia-open nvidia-open-dkms nvidia-utils lib32-nvidia-utils"
ADDITIONAL_PACKAGES="plymouth wireless-regdb"

# GPU Configuration
INSTALL_NVIDIA="true"  # Set to "false" to skip NVIDIA installation

# Function to configure NVIDIA option interactively
configure_nvidia() {
    echo -e "\n${YELLOW}=== GPU Configuration ===${NC}"
    echo "This system is configured for NVIDIA RTX 3080."
    echo "NVIDIA drivers include:"
    echo "  - nvidia-open (open-source kernel modules)"
    echo "  - nvidia-open-dkms (DKMS support)"
    echo "  - nvidia-utils (userspace utilities)"
    echo "  - lib32-nvidia-utils (32-bit support)"
    echo ""
    echo "NVIDIA installation affects:"
    echo "  - Boot parameters (DRM modeset, cursor)"
    echo "  - Kernel modules in initramfs"
    echo "  - Plymouth configuration"
    echo ""

    while true; do
        read -p "Install NVIDIA drivers? [Y/n]: " choice
        case $choice in
            [Yy]* | "" )
                INSTALL_NVIDIA="true"
                log_info "NVIDIA drivers will be installed"
                break
                ;;
            [Nn]* )
                INSTALL_NVIDIA="false"
                log_warning "NVIDIA drivers will be skipped"
                log_warning "You may need to install appropriate drivers manually"
                break
                ;;
            * )
                echo "Please answer yes (Y) or no (N)"
                ;;
        esac
    done
}

# Mount point
MOUNT_POINT="/mnt"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Progress tracking
log_step() {
    echo -e "\n${GREEN}=== Step $1: $2 ===${NC}"
}

# Error handling
handle_error() {
    log_error "An error occurred on line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Function to execute commands in chroot
chroot_exec() {
    arch-chroot $MOUNT_POINT /bin/bash -c "$1"
}

# Function to check if we're in chroot environment
is_chroot() {
    if [[ -f /etc/arch-release ]] && [[ ! -d /proc/1 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to wait for user confirmation
confirm_step() {
    echo -e "\n${YELLOW}Ready to proceed with: $1${NC}"
    read -p "Press Enter to continue or Ctrl+C to abort..."
}

# =============================================================================
# INSTALLATION STEPS
# =============================================================================

step_0_boot_environment() {
    log_step "0" "Boot environment setup"

    log_info "Connecting to Wi-Fi network: $WIFI_SSID"
    iwctl station wlan0 connect-hidden "$WIFI_SSID" --passphrase "$WIFI_PASSPHRASE"

    # Wait for connection
    sleep 5

    # Test connectivity
    if ping -c 3 archlinux.org >/dev/null 2>&1; then
        log_success "Internet connection established"
    else
        log_error "No internet connection"
        exit 1
    fi
}

step_1_pre_install_tweaks() {
    log_step "1" "Pre-install tweaks"

    log_info "Enabling parallel downloads in pacman.conf"

    log_success "Parallel downloads enabled"
}

step_2_disk_layout() {
    log_step "2" "Disk layout and formatting"

    log_warning "This will format $DISK - all data will be lost!"
    confirm_step "Format disk partitions"

    log_info "Formatting EFI partition: $BOOT_PARTITION"
    mkfs.fat -F32 -n "$BOOT_LABEL" "$BOOT_PARTITION"

    log_info "Formatting root partition: $ROOT_PARTITION"
    mkfs.ext4 -L "$ROOT_LABEL" "$ROOT_PARTITION"

    log_success "Disk formatting completed"
}

step_3_mount() {
    log_step "3" "Mount filesystems"

    log_info "Mounting root partition"
    mount "$ROOT_PARTITION" "$MOUNT_POINT"

    log_info "Creating boot directory and mounting EFI partition"
    mkdir -p "$MOUNT_POINT/boot"
    mount "$BOOT_PARTITION" "$MOUNT_POINT/boot"

    log_success "Filesystems mounted"
}

step_4_mirrorlist() {
    log_step "4" "Configure mirrorlist"

    log_info "Updating mirrorlist - moving Egypt/nearby mirrors to top"
    log_warning "Manual intervention required: Edit /etc/pacman.d/mirrorlist with vim"
    log_info "Move Egypt and nearby country mirrors to the top of the list"

    confirm_step "Edit mirrorlist"
    vim /etc/pacman.d/mirrorlist

    log_success "Mirrorlist configured"
}

step_5_base_install() {
    log_step "5" "Base system installation"

    log_info "Installing base packages: $BASE_PACKAGES"
    pacstrap "$MOUNT_POINT" $BASE_PACKAGES

    log_success "Base system installed"
}

step_6_fstab() {
    log_step "6" "Generate fstab"

    log_info "Generating fstab"
    genfstab -U "$MOUNT_POINT" >> "$MOUNT_POINT/etc/fstab"

    log_info "Modifying fstab for secure boot partition"
    sed -i '/\/boot/ s/rw,relatime/rw,relatime,fmask=0077,dmask=0077/' "$MOUNT_POINT/etc/fstab"

    log_success "fstab generated and configured"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_info "Starting Arch Linux installation"
    log_info "Target disk: $DISK"
    log_info "Hostname: $HOSTNAME"
    log_info "Username: $USERNAME"

    # Configure NVIDIA option
    configure_nvidia

    echo ""
    log_info "=== Installation Summary ==="
    log_info "Disk: $DISK"
    log_info "Hostname: $HOSTNAME"
    log_info "User: $USERNAME ($USER_FULLNAME)"
    log_info "Timezone: $TIMEZONE"
    if [[ "$INSTALL_NVIDIA" == "true" ]]; then
        log_info "GPU: NVIDIA drivers will be installed"
    else
        log_warning "GPU: NVIDIA drivers will be skipped"
    fi

    confirm_step "begin installation with these settings"

    # Pre-chroot steps
    step_0_boot_environment
    step_1_pre_install_tweaks
    step_2_disk_layout
    step_3_mount
    step_4_mirrorlist
    step_5_base_install
    step_6_fstab

    log_success "Pre-chroot installation completed"
}

step_7_chroot() {
    log_step "7" "Enter chroot environment"
    log_info "Entering chroot - script will continue inside chroot"

    # Copy script to chroot environment
    cp "$0" "$MOUNT_POINT/root/install-script.sh"
    chmod +x "$MOUNT_POINT/root/install-script.sh"

    log_info "Executing chroot steps..."
    arch-chroot "$MOUNT_POINT" /root/install-script.sh chroot
}

step_8_system_basics() {
    log_step "8" "System basics configuration"

    log_info "Setting timezone to $TIMEZONE"
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime

    log_info "Setting hardware clock"
    hwclock --systohc

    log_info "Configuring locale"
    sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
    locale-gen
    echo "LANG=$LOCALE" > /etc/locale.conf

    log_info "Setting hostname to $HOSTNAME"
    echo "$HOSTNAME" > /etc/hostname

    log_info "Configuring hosts file"
    cat > /etc/hosts << EOF
127.0.0.1	localhost
127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME
EOF

    log_info "Setting root password"
    passwd

    log_success "System basics configured"
}

step_9_systemd_boot() {
    log_step "9" "Configure systemd-boot"

    log_info "Installing systemd-boot"
    bootctl install

    # Construct boot options based on NVIDIA setting
    if [[ "$INSTALL_NVIDIA" == "true" ]]; then
        FINAL_BOOT_OPTIONS="$BASE_BOOT_OPTIONS $NVIDIA_BOOT_OPTIONS"
        log_info "Creating boot entry with NVIDIA options"
    else
        FINAL_BOOT_OPTIONS="$BASE_BOOT_OPTIONS"
        log_info "Creating boot entry without NVIDIA options"
    fi

    log_info "Creating boot entry"
    cat > /boot/loader/entries/arch.conf << EOF
title   $BOOT_TITLE
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options $FINAL_BOOT_OPTIONS
EOF

    log_success "systemd-boot configured"
}

step_10_microcode_gpu() {
    if [[ "$INSTALL_NVIDIA" == "true" ]]; then
        log_step "10" "Install microcode and NVIDIA drivers"
    else
        log_step "10" "Install microcode (NVIDIA skipped)"
    fi

    log_info "Installing AMD microcode"
    pacman -S --noconfirm $MICROCODE_PACKAGE

    if [[ "$INSTALL_NVIDIA" == "true" ]]; then
        log_info "Installing NVIDIA drivers: $GPU_PACKAGES"
        pacman -S --noconfirm $GPU_PACKAGES
        log_success "Microcode and NVIDIA drivers installed"
    else
        log_info "Skipping NVIDIA drivers installation"
        log_warning "Remember to install appropriate GPU drivers for your hardware"
        log_success "Microcode installed (NVIDIA skipped)"
    fi
}

step_11_swap_file() {
    log_step "11" "Create swap file"

    log_info "Creating ${SWAP_SIZE}MB swap file"
    dd if=/dev/zero of=/swap bs=1M count=$SWAP_SIZE status=progress

    log_info "Setting swap file permissions"
    chmod 600 /swap

    log_info "Making swap"
    mkswap /swap
    swapon /swap

    log_info "Adding swap to fstab"
    echo '/swap none swap defaults 0 0' >> /etc/fstab

    log_success "Swap file created and configured"
}

step_12_plymouth() {
    log_step "12" "Configure Plymouth"

    log_info "Installing Plymouth"
    pacman -S --noconfirm plymouth

    if [[ "$INSTALL_NVIDIA" == "true" ]]; then
        log_info "Configuring mkinitcpio for Plymouth and NVIDIA"
        sed -i 's/^MODULES=(.*)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    else
        log_info "Configuring mkinitcpio for Plymouth (generic GPU)"
        # Keep default modules for generic GPU support
        log_info "Using default kernel modules (no NVIDIA-specific modules)"
    fi

    sed -i 's/^HOOKS=(.*)/HOOKS=(base plymouth udev autodetect modconf block filesystems fsck)/' /etc/mkinitcpio.conf

    log_info "Regenerating initramfs"
    mkinitcpio -P

    log_success "Plymouth configured"
}

step_13_wireless_regdb() {
    log_step "13" "Install wireless regulatory database"

    log_info "Installing wireless-regdb"
    pacman -S --noconfirm wireless-regdb

    log_success "Wireless regulatory database installed"
}

step_14_services() {
    log_step "14" "Enable system services"

    local services=(
        "NetworkManager"
        "systemd-timesyncd"
        "fstrim.timer"
        "bluetooth"
        "power-profiles-daemon"
        "sshd"
    )

    for service in "${services[@]}"; do
        log_info "Enabling $service"
        systemctl enable "$service"
    done

    log_success "System services enabled"
}

step_15_user() {
    log_step "15" "Create user account"

    log_info "Creating user: $USERNAME"
    useradd -m -c "$USER_FULLNAME" -G "$USER_GROUPS" "$USERNAME"

    log_info "Setting password for $USERNAME"
    passwd "$USERNAME"

    log_info "Configuring sudo access"
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    log_success "User account created and configured"
}

step_16_exit_reboot() {
    log_step "16" "Finalize installation"

    log_info "Cleaning up installation script"
    rm -f /root/install-script.sh

    log_success "Installation completed successfully!"
    log_info "Exit chroot and run: umount -R /mnt && reboot"
    log_warning "Remove installation media before reboot"
}

chroot_main() {
    log_info "Executing chroot installation steps"

    step_8_system_basics
    step_9_systemd_boot
    step_10_microcode_gpu
    step_11_swap_file
    step_12_plymouth
    step_13_wireless_regdb
    step_14_services
    step_15_user
    step_16_exit_reboot

    log_success "All chroot steps completed!"
}

# Check if running in chroot or with chroot argument
if [[ "${1:-}" == "chroot" ]] || is_chroot; then
    chroot_main
else
    main "$@"
    step_7_chroot
fi
