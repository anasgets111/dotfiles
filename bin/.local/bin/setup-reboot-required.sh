#!/usr/bin/env bash
#
# setup-reboot-required.sh
#
# Installs scripts and Pacman hook for reboot-required notifications.
# Notifies users when system packages are upgraded that require a reboot.
#
# Usage:
#   sudo ./setup-reboot-required.sh
#
# This script performs the following actions:
# 1. Installs notify-reboot-required script to /usr/local/bin/
# 2. Installs check-reboot-required script to /usr/local/bin/
# 3. Creates Pacman hook to trigger checks after package upgrades

set -e

# =============================================================================
# Color and Style Definitions
# =============================================================================
# Escalate to root if needed
if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi
# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Text styles
readonly BOLD='\033[1m'

# Symbols
readonly CHECK='✓'
readonly CROSS='✗'
readonly ARROW='→'
readonly INFO='ℹ'
readonly WARN='⚠'

# =============================================================================
# Styled Output Functions
# =============================================================================

print_success() {
  printf "%b%b%b %s\n" "$GREEN" "$CHECK" "$NC" "$1"
}

print_info() {
  printf "%b%b%b %s\n" "$BLUE" "$INFO" "$NC" "$1"
}

print_warning() {
  printf "%b%b%b %s\n" "$YELLOW" "$WARN" "$NC" "$1"
}

print_error() {
  printf "%b%b%b %s\n" "$RED" "$CROSS" "$NC" "$1"
}

print_header() {
  printf "\n%b%s%b\n" "$CYAN$BOLD" "$1" "$NC"
  printf "%b%s%b\n" "$CYAN" "$(printf '%.0s=' {1..50})" "$NC"
}

print_step() {
  printf "%b%b%b %s\n" "$MAGENTA" "$ARROW" "$NC" "$1"
}

# Display script banner
printf "\n%b%s%b\n" "$CYAN$BOLD" "=== Reboot Required Setup ===" "$NC"
printf "%b%s%b\n\n" "$CYAN" "$(printf '%.0s=' {1..50})" "$NC"

# =============================================================================
# 1. Install notify-reboot-required script
# =============================================================================

print_header "Installing Notification Script"
print_step "Creating /usr/local/bin/notify-reboot-required"

cat << 'EOF' > /usr/local/bin/notify-reboot-required
#!/usr/bin/env bash
#
# notify-reboot-required
#
# Notifies logged-in users that a reboot is recommended after system updates.
# Sends desktop notifications via D-Bus and prints messages to TTY.

set -euo pipefail

# Notification details
readonly HEADER="System Update"
readonly TITLE="Reboot recommended — core components updated!"
readonly MESSAGE="Reboot is recommended due to the upgrade of core system package(s). Please save your work and reboot at your convenience."

# Print to TTY for all users
printf '%s\n' "==> reboot-required: $MESSAGE" >&2

# Send desktop notification to each logged-in user
# shellcheck disable=SC2046
for user in $(users | tr ' ' '\n' | sort | uniq); do
  # See: https://specifications.freedesktop.org/notification-spec/1.2/protocol.html
  busctl --machine="$user@.host" --user call org.freedesktop.Notifications \
    /org/freedesktop/Notifications \
    org.freedesktop.Notifications \
    Notify susssasa{sv}i \
    "$HEADER" \
    0 \
    system-reboot \
    "$TITLE" \
    "$MESSAGE" \
    0 \
    1 urgency y 0x2 \
    10000 &>/dev/null || true
done
EOF

chmod +x /usr/local/bin/notify-reboot-required
print_success "/usr/local/bin/notify-reboot-required installed"

# =============================================================================
# 2. Install check-reboot-required script
# =============================================================================

print_header "Installing Check Script"
print_step "Creating /usr/local/bin/check-reboot-required"

cat << 'EOF' > /usr/local/bin/check-reboot-required
#!/usr/bin/env bash
#
# check-reboot-required
#
# Checks if upgraded packages require a system reboot.
# Called by Pacman hook after package upgrades.

set -euo pipefail

# Notify function - calls the notification script and exits
notify_reboot() {
  /usr/local/bin/notify-reboot-required
  exit 0
}

# Read upgraded packages from stdin (provided by Pacman hook)
targets=$(tee /dev/null)

# Get running kernel package name
kver="$(uname -r)"
pkgbase_path="/usr/lib/modules/$kver/pkgbase"
if [[ -r "$pkgbase_path" ]]; then
  kernelpkg="$(<"$pkgbase_path")"
else
  # Conservative approach: notify if we can't determine kernel package
  notify_reboot
fi

# Check each upgraded package
for target in $targets; do
  case "$target" in
    # Running kernel package updated
    "$kernelpkg") notify_reboot ;;

    # Microcode updates
    amd-ucode|intel-ucode) notify_reboot ;;

    # NVIDIA drivers
    nvidia|nvidia-open) notify_reboot ;;

    # Filesystem tools - only notify if filesystem is in use
    btrfs-progs)
      [[ -n "$(mount -t btrfs)" ]] && notify_reboot
      ;;
    xfsprogs)
      [[ -n "$(mount -t xfs)" ]] && notify_reboot
      ;;
    e2fsprogs)
      [[ -n "$(mount -t ext4)" ]] && notify_reboot
      ;;

    # Everything else matched by the hook (systemd, wayland, mesa, initramfs tools, firmware, etc.)
    *)
      notify_reboot
      ;;
  esac
done

exit 0
EOF

chmod +x /usr/local/bin/check-reboot-required
print_success "/usr/local/bin/check-reboot-required installed"

# =============================================================================
# 3. Create Pacman hook
# =============================================================================

print_header "Creating Pacman Hook"
print_step "Setting up /etc/pacman.d/hooks/90-reboot-required.hook"

hook_dir="/etc/pacman.d/hooks"
hook_file="$hook_dir/90-reboot-required.hook"

mkdir -p "$hook_dir"

cat << 'EOF' > "$hook_file"
[Trigger]
Operation = Upgrade
Type = Package

# Microcode updates
Target = amd-ucode
Target = intel-ucode

# Filesystem tools
Target = btrfs-progs
Target = e2fsprogs
Target = xfsprogs
Target = cryptsetup

# Kernel packages
Target = linux
Target = linux-lts
Target = linux-hardened
Target = linux-zen
Target = linux-firmware

# Graphics drivers
Target = nvidia
Target = nvidia-open
Target = mesa

# System and init components
Target = systemd*
Target = mkinitcpio*
Target = booster*
Target = dracut*

# Wayland/X11 components
Target = wayland
Target = egl-wayland
Target = xf86-video-*
Target = xorg-server*
Target = xorg-fonts*

[Action]
Description = Check if reboot is required after system package upgrades
When = PostTransaction
NeedsTargets
Exec = /usr/local/bin/check-reboot-required
EOF

print_success "$hook_file created"

# =============================================================================
# Summary
# =============================================================================

print_header "Setup Complete!"
print_success "Scripts installed to /usr/local/bin/"
print_success "Pacman hook created at $hook_file"
print_success "System will now notify users when reboot is required after package upgrades"
print_info "Note: Run with sudo if installing system-wide"

printf "\n%b%s%b\n" "$GREEN$BOLD" "🎉 Setup finished successfully!" "$NC"