#!/usr/bin/env bash
# =============================================================================
# Arch Linux Custom Installation Script
# Systems: Wolverine (Ryzen 5900X + RTX 3080) | Mentalist (Intel i9 13900H)
# =============================================================================

set -euo pipefail
trap 'printf "%b\n" "${RED:-}[ERROR]${NC:-} Command failed at line ${LINENO}: ${BASH_COMMAND:-unknown}"; exit 1' ERR

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

log_info() { printf '%b\n' "${BLUE}[INFO]${NC} $1"; }
log_success() { printf '%b\n' "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { printf '%b\n' "${YELLOW}[WARNING]${NC} $1"; }
log_error() { printf '%b\n' "${RED}[ERROR]${NC} $1"; }
log_step() {
	local title="$1"
	printf '\n%b\n' "${GREEN}=== Step ${CURRENT_STEP}: ${title} ===${NC}"
}

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

# Derived (set after host detection/resume)
declare HOSTNAME=""
declare IS_PC=false
declare -i CURRENT_STEP=1
declare STATE_FILE="/tmp/arch-install.state"

# Partition selections (set interactively)
declare BOOT_PART=""
declare ROOT_PART=""

# PACKAGE ARRAYS - OFFICIAL REPOS (for pacstrap)
# =============================================================================

PKGS_COMMON=(
	# Base System
	base base-devel linux linux-firmware networkmanager mandoc man

	# Hardware & Firmware
	bluez gnome-firmware i2c-tools lshw plymouth usbutils wireless-regdb zram-generator

	# Audio & Accessibility
	espeak-ng pipewire-alsa pipewire-jack pipewire-pulse speech-dispatcher wireplumber

	# System Utilities
	gnome-keyring ly mkcert mold pacman-contrib pkgstats xdg-desktop-portal-gnome

	# Shell & Terminal
	bash-completion bat btop cliphist dysk expac eza fastfetch fd fish fzf jq kitty starship tealdeer zoxide xsel

	# CLI Tools
	7zip curl ffmpegthumbnailer git git-filter-repo git-lfs inotify-tools
	less neovim ripgrep rsync shfmt stow tokei tree-sitter-cli unrar unzip wget zip

	# Development
	bun just rustup

	# Desktop Environment & Apps
	gnome-calculator gnome-disk-utility gnome-text-editor kdeconnect
	mission-center nautilus-image-converter papers qbittorrent simple-scan

	# Communication
	telegram-desktop thunderbird

	# Media & Design
	mpv-mpris satty zed

	# Theming
	kvantum qt6ct tela-circle-icon-theme-dracula

	# Fonts
	adobe-source-code-pro-fonts gnu-free-fonts inter-font noto-fonts-emoji noto-fonts-extra opendesktop-fonts
	otf-font-awesome terminus-font ttf-bitstream-vera ttf-cascadia-code-nerd ttf-fira-code ttf-firacode-nerd ttf-liberation
	ttf-roboto-mono-nerd ttf-scheherazade-new
)

PKGS_PHP=(
	# PHP Stack
	composer dnsmasq mariadb-clients postgresql-libs nginx php php-fpm php-gd php-igbinary php-imagick php-pgsql php-redis php-snmp php-sodium php-sqlite php-xsl podman-compose
)

PKGS_MENTALIST=(
	# Hardware (Intel)
	acpi_call brightnessctl intel-media-driver intel-ucode vulkan-intel

	# Desktop (Niri)
	niri pipewire-libcamera pipewire-v4l2

	# Database
	unixodbc
)

PKGS_WOLVERINE=(
	# Hardware (AMD + NVIDIA)
	amd-ucode lib32-nvidia-utils libva-nvidia-driver nvidia-open nvidia-settings nvidia-utils

	# Hyprland WM
	hyprland hyprpicker hyprshot uwsm xdg-desktop-portal-hyprland

	# Gaming
	gamemode mangohud steam

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

apply_pacman_defaults() {
	local pacman_conf_path="$1"

	sed -i \
		-e 's/^#ParallelDownloads/ParallelDownloads/' \
		-e 's/^#Color/Color/' \
		-e '/\[multilib\]/,/Include/s/^#//' \
		"$pacman_conf_path"
	grep -q "^ILoveCandy" "$pacman_conf_path" || sed -i '/^Color/a ILoveCandy' "$pacman_conf_path"
}

run_as_user() {
	local script="$1"
	shift
	runuser -u "$USERNAME" -- bash -lc "$script" bash "$@"
}

derive_is_pc() {
	IS_PC=false
	[[ "$HOSTNAME" == "Wolverine" ]] && IS_PC=true
}

save_state() {
	cat >"$STATE_FILE" <<EOF
CURRENT_STEP=$CURRENT_STEP
HOSTNAME="$HOSTNAME"
BOOT_PART="$BOOT_PART"
ROOT_PART="$ROOT_PART"
EOF
}

load_state() {
	[[ -f "$STATE_FILE" ]] || return 1
	# shellcheck disable=SC1090
	source "$STATE_FILE"
	: "${CURRENT_STEP:=1}"
	: "${HOSTNAME:=}"
	derive_is_pc
	: "${BOOT_PART:=}"
	: "${ROOT_PART:=}"
	return 0
}

clear_state() {
	rm -f "$STATE_FILE"
}

run_step() {
	local step="$1"
	local fn="$2"
	local save_next="${3:-true}"

	CURRENT_STEP="$step"
	save_state
	"$fn"

	if [[ "$save_next" == "true" ]]; then
		CURRENT_STEP=$((step + 1))
		save_state
	fi
}

detect_host() {
	log_step "Detecting target system"

	local cpu_vendor_raw cpu_name
	cpu_vendor_raw=$(awk -F: '/vendor_id/{print tolower($2); exit}' /proc/cpuinfo | xargs)
	cpu_name=$(awk -F: '/model name/{sub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo)
	[[ -n "$cpu_name" ]] && log_info "Detected CPU: $cpu_name"

	case "$cpu_vendor_raw" in
	*authenticamd*)
		HOSTNAME="Wolverine"
		IS_PC=true
		log_success "Auto-detected: $HOSTNAME (CPU: amd)"
		;;
	*genuineintel*)
		HOSTNAME="Mentalist"
		IS_PC=false
		log_success "Auto-detected: $HOSTNAME (CPU: intel)"
		;;
	*)
		log_error "Unsupported CPU vendor for this script."
		log_error "Detected CPU vendor: $cpu_vendor_raw"
		log_info "Supported combinations:"
		log_info "  - amd => Wolverine"
		log_info "  - intel => Mentalist"
		exit 1
		;;
	esac
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

# =============================================================================
# STEP FUNCTIONS
# =============================================================================

connectivity() {
	log_step "Checking connectivity"
	local wifi_iface=""

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
	printf '\n'

	iwctl station "$wifi_iface" connect-hidden "$WIFI_SSID" --passphrase "$wifi_pass"

	local max_wait_seconds=20
	local attempt=0
	until ping -c 1 -W 3 archlinux.org &>/dev/null; do
		((++attempt >= max_wait_seconds)) && {
			log_error "Failed to connect after ${max_wait_seconds}s. Please check manually."
			exit 1
		}
		sleep 1
	done

	log_success "Connected to Wi-Fi"
}

select_partitions() {
	log_step "Partition selection"

	log_info "Detected partitions:"
	lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
	printf '\n'

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
		local part_dev="${partitions[$i]%% *}"
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
	BOOT_PART="${partitions[$boot_selected]%% *}"

	while true; do
		root_selected=$(menu_select "Select ROOT partition" "$root_default_zero" "${partition_options[@]}")
		ROOT_PART="${partitions[$root_selected]%% *}"
		[[ "$BOOT_PART" != "$ROOT_PART" ]] && break
		log_warning "BOOT and ROOT cannot be the same partition. Please choose again."
	done

	log_success "Selected: BOOT=$BOOT_PART, ROOT=$ROOT_PART"
}

format_partitions() {
	log_step "Formatting partitions"

	local summary_sep="=============================================="
	local system_type="Laptop (Intel)"
	$IS_PC && system_type="PC (AMD + NVIDIA)"
	printf '\n'
	printf '%s\n' "$summary_sep"
	printf '%s\n' "           INSTALLATION SUMMARY"
	printf '%s\n' "$summary_sep"
	printf 'Hostname:       %s\n' "$HOSTNAME"
	printf 'Boot Partition: %s\n' "$BOOT_PART"
	printf 'Root Partition: %s\n' "$ROOT_PART"
	printf 'Username:       %s\n' "$USERNAME"
	printf 'Timezone:       %s\n' "$TIMEZONE"
	printf 'Locale:         %s\n' "$LOCALE"
	printf 'Type:           %s\n' "$system_type"
	printf '%s\n' "$summary_sep"
	printf '\n'

	log_warning "This will ERASE all data on $BOOT_PART and $ROOT_PART!"
	read -rp "Are you sure you want to continue? [y/N]: " response
	[[ "$response" =~ ^[Yy]$ ]] || {
		log_error "Aborted by user"
		exit 1
	}

	if mountpoint -q "$MOUNT_POINT"; then
		log_info "Unmounting existing filesystems under $MOUNT_POINT"
		if ! cd / && umount -R "$MOUNT_POINT"; then
			log_error "Failed to unmount $MOUNT_POINT. Resolve busy mounts and retry."
			exit 1
		fi
	fi

	log_info "Formatting BOOT partition as FAT32"
	mkfs.fat -F32 -n BOOT "$BOOT_PART"

	log_info "Formatting ROOT partition as ext4"
	mkfs.ext4 -F -L Archlinux "$ROOT_PART"

	log_success "Partitions formatted"
}

mount_filesystems() {
	log_step "Mounting filesystems"

	mountpoint -q "$MOUNT_POINT" && cd / && umount -R "$MOUNT_POINT"
	mount -o noatime "$ROOT_PART" "$MOUNT_POINT"
	mount --mkdir -o noatime,umask=0077 "$BOOT_PART" "$MOUNT_POINT/boot"

	# Mount required Work partition so it's available in chroot
	local work_part
	work_part=$(blkid -L Work || true)
	if [[ -z "$work_part" ]]; then
		log_error "Required Work partition (label: Work) not found"
		exit 1
	fi

	mount --mkdir -o noatime "$work_part" "$MOUNT_POINT/mnt/Work"

	log_success "Filesystems mounted"
}

mirrorlist() {
	log_step "Optimizing mirrors with reflector"

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

pacman_defaults() {
	log_step "Configuring pacman defaults (live environment)"

	log_info "Enabling ParallelDownloads, Color, ILoveCandy, multilib"
	apply_pacman_defaults /etc/pacman.conf

	log_success "Pacman defaults configured"
}

pacstrap_base() {
	log_step "Installing base system"

	local packages=("${PKGS_COMMON[@]}")
	$IS_PC && packages+=("${PKGS_WOLVERINE[@]}") || packages+=("${PKGS_MENTALIST[@]}")

	read -rp "Do you want to install the PHP stack? [y/N]: " install_php
	if [[ "$install_php" =~ ^[Yy]$ ]]; then
		packages+=("${PKGS_PHP[@]}")
		log_info "PHP stack added."
	fi

	log_info "Installing ${#packages[@]} packages..."
	pacstrap -K "$MOUNT_POINT" "${packages[@]}"

	log_success "Base system installed"
}

fstab() {
	log_step "Generating fstab"

	genfstab -L "$MOUNT_POINT" >"$MOUNT_POINT/etc/fstab"

	# Auxiliary partitions
	local opts="nosuid,nodev,nofail,x-gvfs-show,x-systemd.makedir,noatime"
	for label in "${AUX_LABELS[@]}"; do
		blkid -L "$label" &>/dev/null || continue
		local entry="LABEL=$label  /mnt/$label  ext4  $opts  0 2"
		if grep -qE "^[[:space:]]*LABEL=${label}[[:space:]]+" "$MOUNT_POINT/etc/fstab"; then
			log_info "Updating fstab options for $label"
			sed -i "s|^[[:space:]]*LABEL=${label}[[:space:]].*|$entry|" "$MOUNT_POINT/etc/fstab"
		else
			log_info "Adding $label partition to fstab"
			printf '%s\n' "$entry" >>"$MOUNT_POINT/etc/fstab"
		fi
	done

	log_success "fstab generated"
}

prepare_chroot() {
	log_step "Preparing chroot"

	# Copy the script to chroot (running from /tmp ensures stable source)
	install -m 0755 /tmp/arch-install.sh "$MOUNT_POINT/root/install.sh"

	# Save config for chroot
	printf '%s\n' "HOSTNAME=\"$HOSTNAME\"" >"$MOUNT_POINT/root/install.conf"

	if [[ -f "$MOUNT_POINT/root/install.state" ]]; then
		log_info "Existing chroot state found; keeping it for resume"
	else
		cp "$STATE_FILE" "$MOUNT_POINT/root/install.state"
	fi

	# Copy optimized mirrorlist and tune target pacman defaults
	cp /etc/pacman.d/mirrorlist "$MOUNT_POINT/etc/pacman.d/mirrorlist"
	apply_pacman_defaults "$MOUNT_POINT/etc/pacman.conf"
	log_info "Copied mirrorlist and updated target pacman defaults"

	log_info "Entering chroot..."
	arch-chroot "$MOUNT_POINT" /root/install.sh chroot
}

# =============================================================================
# CHROOT FUNCTIONS
# =============================================================================

chroot_basics() {
	log_step "System basics"

	log_info "Setting timezone"
	ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
	hwclock --systohc

	log_info "Setting locale"
	sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
	locale-gen
	printf '%s\n' "LANG=$LOCALE" >/etc/locale.conf
	if ! [[ -f /etc/vconsole.conf ]] || ! grep -qE '^[[:space:]]*KEYMAP=' /etc/vconsole.conf; then
		log_warning "/etc/vconsole.conf missing or incomplete. Creating default."
		printf '%s\n' "KEYMAP=$VCONSOLE_KEYMAP" >/etc/vconsole.conf
	fi

	log_info "Setting hostname: $HOSTNAME"
	printf '%s\n' "$HOSTNAME" >/etc/hostname
	cat >/etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

	set_password_with_retry "root" passwd

	log_success "System basics configured"
}

chroot_bootloader() {
	log_step "Installing bootloader"

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

chroot_repos() {
	log_step "Setting up AUR repos and packages"
	log_info "Appending Chaotic-AUR and Omarchy repos in installed system pacman.conf"

	# Chaotic-AUR
	log_info "Setting up Chaotic-AUR"
	pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
	pacman-key --lsign-key 3056513887B78AEB
	pacman -U --needed --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
	pacman -U --needed --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

	if grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
		log_info "[chaotic-aur] already exists in pacman.conf"
	else
		cat >>/etc/pacman.conf <<EOF

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
	fi
	log_info "Added repo [chaotic-aur]"

	# Omarchy
	log_info "Setting up Omarchy"
	if grep -q '^\[omarchy\]' /etc/pacman.conf; then
		log_info "[omarchy] already exists in pacman.conf"
	else
		cat >>/etc/pacman.conf <<EOF

[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/\$arch
EOF
	fi
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

	pacman -S --needed --noconfirm "${aur_packages[@]}"

	log_success "AUR packages installed"
}

chroot_zram() {
	log_step "Configuring ZRAM"

	cat >/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
EOF

	cat >/etc/sysctl.d/99-zram.conf <<'EOF'
vm.swappiness = 180
EOF

	log_success "ZRAM configured"
}

chroot_initramfs() {
	log_step "Configuring initramfs"

	if $IS_PC; then
		log_info "Adding NVIDIA modules"
		sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
	fi
	sed -i 's/^HOOKS=.*/HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)/' /etc/mkinitcpio.conf

	mkinitcpio -P

	log_success "Initramfs regenerated"
}

chroot_services() {
	log_step "Enabling services"

	local services=(
		NetworkManager
		systemd-timesyncd
		fstrim.timer
		bluetooth
		ly@tty2
		fwupd-refresh.timer
	)

	if $IS_PC; then
		services+=(nvidia-persistenced)
	else
		services+=(asusd)
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

chroot_user() {
	log_step "Creating user"

	if id -u "$USERNAME" &>/dev/null; then
		log_info "User $USERNAME already exists, skipping creation"
	else
		log_info "Creating user: $USERNAME"
		useradd -m -c "$USER_FULLNAME" -G "$USER_GROUPS" -s /usr/bin/fish "$USERNAME"
	fi

	set_password_with_retry "$USERNAME" passwd "$USERNAME"

	log_info "Enabling sudo for wheel group"
	sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

	log_success "User created"
}

chroot_post_user() {
	log_step "Post-install user bootstrap"

	local dots_dir="/mnt/Work/1Progs/Dots"
	local backup_script="$dots_dir/bin/.local/bin/backup-home"
	local stow_packages=(bin kitty quickshell fish nvim mpv)
	if $IS_PC; then
		stow_packages+=(hypr)
	else
		stow_packages+=(niri)
	fi

	if ! mountpoint -q /mnt/Work; then
		log_info "/mnt/Work is not mounted; attempting mount from fstab..."
		if ! mount --mkdir /mnt/Work; then
			log_error "Failed to mount /mnt/Work. Cannot continue post-user bootstrap."
			return 1
		fi
	fi

	if [[ ! -d "$dots_dir" ]]; then
		log_warning "Dots directory not found at $dots_dir. Skipping restore/stow."
		return 0
	fi

	if ! run_as_user "\"$backup_script\" -r"; then
		log_warning "backup-home restore failed (or script missing); continuing."
	fi

	if ! run_as_user 'rm -f "$HOME/.bashrc" "$HOME/.bash_profile"'; then
		log_warning "Failed removing default bash files; continuing."
	fi

	if ! run_as_user 'cd "$1" && shift && stow -t "$HOME" "$@"' \
		"$dots_dir" "${stow_packages[@]}"; then
		log_warning "Stow failed; continuing."
	fi

	if ! run_as_user 'yay -S --needed --noconfirm --removemake --cleanafter antigravity quickshell-git'; then
		log_warning "yay install failed for antigravity/quickshell-git; continuing."
	fi

	log_success "Post-user bootstrap complete"
}

chroot_cleanup() {
	log_step "Cleanup"

	rm -f /root/install.sh /root/install.conf
	clear_state

	printf '\n'
	log_success "Installation complete!"
	printf '\n'
	printf '%s\n' "Next steps:"
	printf '%s\n' "  1. Exit chroot (will happen automatically)"
	printf '%s\n' "  2. Script will unmount and reboot"
	printf '\n'
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
	local banner_sep="========================================"
	printf '\n'
	printf '%s\n' "$banner_sep"
	printf '%s\n' "   Arch Linux Installation Script"
	printf '%s\n' "$banner_sep"
	printf '\n'

	reset_state() {
		clear_state
		CURRENT_STEP=1
		HOSTNAME=""
		IS_PC=false
		BOOT_PART=""
		ROOT_PART=""
	}

	if [[ -f "$STATE_FILE" ]]; then
		if load_state; then
			local resume_options=(
				"Resume previous install"
				"Start new install"
			)
			local resume_choice
			resume_choice=$(menu_select "Existing install state found" 0 "${resume_options[@]}")
			((resume_choice == 1)) && reset_state
		else
			log_warning "Failed to load state file, starting fresh"
			reset_state
		fi
	fi

	if ((CURRENT_STEP == 4)); then
		log_warning "Step 4 is non-rerunnable, skipping to step 5"
		CURRENT_STEP=5
	fi

	local -a live_steps=(
		detect_host
		connectivity
		select_partitions
		format_partitions
		mount_filesystems
		mirrorlist
		pacman_defaults
		pacstrap_base
		fstab
		prepare_chroot
	)
	while ((CURRENT_STEP <= 10)); do
		local fn="${live_steps[CURRENT_STEP - 1]:-}"
		[[ -n "$fn" ]] || {
			log_error "Invalid CURRENT_STEP: $CURRENT_STEP"
			exit 1
		}
		run_step "$CURRENT_STEP" "$fn"
	done

	log_info "Chroot completed successfully"
	clear_state
	printf '\n'
	read -rsn1 -p "Press any key to unmount and reboot (Ctrl+C to cancel)..."
	printf '\n'

	if umount -R "$MOUNT_POINT" 2>/dev/null; then
		log_success "Unmounted $MOUNT_POINT"
	else
		log_warning "Failed to unmount $MOUNT_POINT cleanly; rebooting anyway."
	fi

	log_success "Ready to reboot"
	sleep 2
	reboot
}

chroot_main() {
	# Load config
	source /root/install.conf
	derive_is_pc
	STATE_FILE="/root/install.state"

	if ! load_state; then
		CURRENT_STEP=11
		save_state
	fi

	if ((CURRENT_STEP < 11)); then
		CURRENT_STEP=11
	fi

	while ((CURRENT_STEP <= 19)); do
		case "$CURRENT_STEP" in
		11) run_step 11 chroot_basics ;;
		12) run_step 12 chroot_bootloader ;;
		13) run_step 13 chroot_repos ;;
		14) run_step 14 chroot_zram ;;
		15) run_step 15 chroot_initramfs ;;
		16) run_step 16 chroot_services ;;
		17) run_step 17 chroot_user ;;
		18) run_step 18 chroot_post_user ;;
		19)
			run_step 19 chroot_cleanup false
			break
			;;
		*)
			log_error "Invalid CURRENT_STEP in chroot: $CURRENT_STEP"
			exit 1
			;;
		esac
	done
}

if [[ "${1:-}" == "chroot" ]]; then
	chroot_main
else
	main
fi
