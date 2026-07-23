#!/usr/bin/env bash
# =============================================================================
# Arch Linux Custom Installation Script
# Systems: Wolverine (Ryzen 5900X + RTX 3080) | Mentalist (Intel i9 13900H)
# =============================================================================

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

# COLORS & LOGGING

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

log_info() { printf '%b\n' "${BLUE}[INFO]${COLOR_RESET} $1"; }
log_success() { printf '%b\n' "${GREEN}[SUCCESS]${COLOR_RESET} $1"; }
log_warning() { printf '%b\n' "${YELLOW}[WARNING]${COLOR_RESET} $1"; }
log_error() { printf '%b\n' "${RED}[ERROR]${COLOR_RESET} $1"; }
log_step() {
	local title="$1"
	printf '\n%b\n' "${GREEN}=== ${title} ===${COLOR_RESET}"
}

# FIXED CONFIGURATION

TIMEZONE="Africa/Cairo"
LOCALE="en_US.UTF-8"
VCONSOLE_KEYMAP="us"
USERNAME="anas"
USER_FULLNAME="Anas Khalifa"
USER_GROUPS="wheel"
WIFI_SSID="Ghuzlan_5G"
TARGET_ROOT="/mnt"

# Installation plan (set before formatting, then persisted for resume)
declare SYSTEM_PROFILE=""
declare HOSTNAME=""
declare SYSTEM_DESCRIPTION=""
declare INSTALL_PHP_STACK=false
declare NEXT_CHECKPOINT=""
declare INSTALL_STATE_FILE="$RUNTIME_DIR/state"
INSTALL_COMPLETE_MARKER="complete"

# Partition selections (set interactively)
declare BOOT_PARTITION=""
declare ROOT_PARTITION=""

# OFFICIAL REPOSITORY PACKAGES (pacstrap)

COMMON_PACKAGES=(
	# Base System
	base base-devel linux linux-firmware networkmanager mandoc man

	# Hardware & Firmware
	bluez gnome-firmware i2c-tools lshw plymouth wireless-regdb zram-generator

	# Audio & Accessibility
	espeak-ng pipewire-alsa pipewire-jack pipewire-pulse speech-dispatcher wireplumber

	# System Utilities
	gnome-keyring ly mkcert mold pacman-contrib pkgstats xdg-desktop-portal-gnome

	# Shell & Terminal
	bash-completion bat btop cliphist dysk expac eza fastfetch fd fish fzf kitty starship tealdeer zoxide xsel

	# CLI Tools
	7zip curl ffmpegthumbnailer git git-filter-repo git-lfs inotify-tools
	less neovim ripgrep rsync shfmt slurp stow tokei tree-sitter-cli unrar wget zip

	# Development
	bun just rustup

	# Desktop Environment & Apps
	gnome-calculator gnome-disk-utility gnome-text-editor kdeconnect
	mission-center nautilus-image-converter papers qbittorrent simple-scan

	# Communication
	telegram-desktop thunderbird

	# Media & Design
	cava mpv-mpris satty zed

	# Theming
	kvantum qt6ct tela-circle-icon-theme-dracula

	# Fonts
	adobe-source-code-pro-fonts gnu-free-fonts inter-font noto-fonts-emoji noto-fonts-extra opendesktop-fonts
	otf-font-awesome terminus-font ttf-bitstream-vera ttf-cascadia-code-nerd ttf-fira-code ttf-firacode-nerd ttf-liberation
	ttf-roboto-mono-nerd ttf-scheherazade-new
)

PHP_PACKAGES=(
	# PHP Stack
	composer dnsmasq mariadb-clients nginx php-fpm php-gd php-imagick php-pgsql php-redis php-snmp php-sodium php-sqlite php-xsl podman-compose
)

MENTALIST_PACKAGES=(
	# Hardware (Intel)
	acpi_call brightnessctl intel-media-driver intel-ucode vulkan-intel

	# Desktop (Niri)
	niri pipewire-libcamera pipewire-v4l2

	# Database
	unixodbc
)

WOLVERINE_PACKAGES=(
	# Hardware (AMD + NVIDIA)
	amd-ucode lib32-nvidia-utils libva-nvidia-driver nvidia-open nvidia-settings

	# Hyprland WM
	hyprland hyprpicker hyprshot uwsm xdg-desktop-portal-hyprland

	# Gaming
	gamemode mangohud steam

	# Peripherals
	solaar
)

# ADDITIONAL BINARY REPOSITORY PACKAGES (post-chroot pacman)

COMMON_EXTRA_PACKAGES=(
	# Package management
	rate-mirrors yay
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

MENTALIST_EXTRA_PACKAGES=(
	asusctl
)

WOLVERINE_EXTRA_PACKAGES=(
	heroic-games-launcher-bin
)

# Auxiliary partition labels to auto-mount
AUXILIARY_PARTITION_LABELS=(Work Media Games)

# Populated once from SYSTEM_PROFILE; consumers do not branch on the machine.
declare -a PROFILE_PACKAGES=()
declare -a PROFILE_EXTRA_PACKAGES=()
declare -a PROFILE_SERVICES=()
declare -a PROFILE_STOW_PACKAGES=()
declare -a PROFILE_INITRAMFS_MODULES=()

# HELPER FUNCTIONS

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
	local pacman_config="$1"

	sed -i \
		-e 's/^#ParallelDownloads/ParallelDownloads/' \
		-e 's/^#Color/Color/' \
		-e '/\[multilib\]/,/Include/s/^#//' \
		"$pacman_config"
	grep -q "^ILoveCandy" "$pacman_config" || sed -i '/^Color/a ILoveCandy' "$pacman_config"
}

run_as_user() {
	local command_string="$1"
	shift
	sudo -iu "$USERNAME" -- bash -c "$command_string" bash "$@"
}

apply_system_profile() {
	PROFILE_PACKAGES=()
	PROFILE_EXTRA_PACKAGES=()
	PROFILE_SERVICES=()
	PROFILE_STOW_PACKAGES=()
	PROFILE_INITRAMFS_MODULES=()

	case "$SYSTEM_PROFILE" in
	wolverine)
		HOSTNAME="Wolverine"
		SYSTEM_DESCRIPTION="PC (AMD + NVIDIA)"
		PROFILE_PACKAGES=("${WOLVERINE_PACKAGES[@]}")
		PROFILE_EXTRA_PACKAGES=("${WOLVERINE_EXTRA_PACKAGES[@]}")
		PROFILE_SERVICES=(nvidia-persistenced)
		PROFILE_STOW_PACKAGES=(hypr)
		PROFILE_INITRAMFS_MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
		;;
	mentalist)
		HOSTNAME="Mentalist"
		SYSTEM_DESCRIPTION="Laptop (Intel)"
		PROFILE_PACKAGES=("${MENTALIST_PACKAGES[@]}")
		PROFILE_EXTRA_PACKAGES=("${MENTALIST_EXTRA_PACKAGES[@]}")
		PROFILE_SERVICES=(asusd)
		PROFILE_STOW_PACKAGES=(niri)
		;;
	*)
		log_error "Unknown system profile: ${SYSTEM_PROFILE:-<empty>}"
		return 1
		;;
	esac
}

save_install_state() {
	local state_file="${1:-$INSTALL_STATE_FILE}"
	local state_tmp
	# One field per line: checkpoint, profile, boot partition, root partition, PHP choice.
	(
		umask 077
		state_tmp=$(mktemp "${state_file}.tmp.XXXXXX")
		trap 'rm -f -- "$state_tmp"' EXIT
		printf '%s\n' "$NEXT_CHECKPOINT" "$SYSTEM_PROFILE" "$BOOT_PARTITION" "$ROOT_PARTITION" "$INSTALL_PHP_STACK" >"$state_tmp"
		mv -f -- "$state_tmp" "$state_file"
		trap - EXIT
	)
}

load_install_state() {
	[[ -f "$INSTALL_STATE_FILE" && ! -L "$INSTALL_STATE_FILE" && -O "$INSTALL_STATE_FILE" ]] || return 1
	local -a state_fields
	mapfile -t state_fields <"$INSTALL_STATE_FILE"
	((${#state_fields[@]} == 5)) || return 1
	local next_checkpoint="${state_fields[0]}"
	local system_profile="${state_fields[1]}"
	local boot_partition="${state_fields[2]}"
	local root_partition="${state_fields[3]}"
	local install_php_stack="${state_fields[4]}"
	[[ "$system_profile" == wolverine || "$system_profile" == mentalist ]] || return 1
	[[ "$install_php_stack" == true || "$install_php_stack" == false ]] || return 1

	NEXT_CHECKPOINT="$next_checkpoint"
	SYSTEM_PROFILE="$system_profile"
	BOOT_PARTITION="$boot_partition"
	ROOT_PARTITION="$root_partition"
	INSTALL_PHP_STACK="$install_php_stack"
	apply_system_profile
}

clear_install_state() {
	rm -f "$INSTALL_STATE_FILE"
}

run_resumable_steps() {
	local step_functions=("$@")
	local step_index=0

	[[ "$NEXT_CHECKPOINT" == "$INSTALL_COMPLETE_MARKER" ]] && return 0
	if [[ -n "$NEXT_CHECKPOINT" ]]; then
		local checkpoint_found=false
		for step_index in "${!step_functions[@]}"; do
			[[ "${step_functions[step_index]}" == "$NEXT_CHECKPOINT" ]] && {
				checkpoint_found=true
				break
			}
		done
		[[ "$checkpoint_found" == true ]] || {
			log_error "Unknown resume checkpoint: $NEXT_CHECKPOINT"
			return 1
		}
	fi

	if ((step_index < ${#step_functions[@]})); then
		NEXT_CHECKPOINT="${step_functions[step_index]}"
		save_install_state
	fi

	while ((step_index < ${#step_functions[@]})); do
		"${step_functions[step_index]}"
		((++step_index))
		NEXT_CHECKPOINT="${step_functions[step_index]:-$INSTALL_COMPLETE_MARKER}"
		save_install_state
	done
}

detect_system_profile() {
	log_step "Detecting target system"

	local cpu_vendor cpu_name
	cpu_vendor=$(awk -F: '/vendor_id/{print tolower($2); exit}' /proc/cpuinfo | xargs)
	cpu_name=$(awk -F: '/model name/{sub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo)
	[[ -n "$cpu_name" ]] && log_info "Detected CPU: $cpu_name"

	case "$cpu_vendor" in
	*authenticamd*)
		SYSTEM_PROFILE="wolverine"
		;;
	*genuineintel*)
		SYSTEM_PROFILE="mentalist"
		;;
	*)
		log_error "Unsupported CPU vendor for this script."
		log_error "Detected CPU vendor: $cpu_vendor"
		log_info "Supported combinations:"
		log_info "  - amd => Wolverine"
		log_info "  - intel => Mentalist"
		exit 1
		;;
	esac

	apply_system_profile
	log_success "Auto-detected: $HOSTNAME ($SYSTEM_DESCRIPTION)"
}

select_from_menu() {
	local prompt="$1"
	local default_index="$2"
	shift 2
	local options=("$@")
	local selected_index="$default_index"
	local key i _

	printf "%s\n" "$prompt" >/dev/tty
	printf "Use ↑/↓ and Enter.\n" >/dev/tty
	for _ in "${options[@]}"; do
		printf "\n" >/dev/tty
	done

	printf "\033[?25l" >/dev/tty
	while true; do
		printf "\033[%dA" "${#options[@]}" >/dev/tty
		for i in "${!options[@]}"; do
			if ((i == selected_index)); then
				printf "\r\033[2K  > %s\n" "${options[$i]}" >/dev/tty
			else
				printf "\r\033[2K    %s\n" "${options[$i]}" >/dev/tty
			fi
		done

		IFS= read -rsn1 key </dev/tty
		if [[ "$key" == $'\x1b' ]]; then
			IFS= read -rsn2 -t 0.05 key </dev/tty || key=""
			case "$key" in
			"[A") selected_index=$(((selected_index - 1 + ${#options[@]}) % ${#options[@]})) ;;
			"[B") selected_index=$(((selected_index + 1) % ${#options[@]})) ;;
			esac
		elif [[ -z "$key" ]]; then
			break
		fi
	done
	printf "\033[?25h" >/dev/tty
	printf "\n" >/dev/tty
	printf '%s\n' "$selected_index"
}

# LIVE ENVIRONMENT STEPS

ensure_network_connection() {
	log_step "Checking connectivity"
	local wifi_interface="" interface_path

	if ping -c 1 -W 3 archlinux.org &>/dev/null; then
		log_success "Internet connection available"
		return 0
	fi

	log_warning "No internet connection detected"
	for interface_path in /sys/class/net/wl*; do
		[[ -e "$interface_path" ]] && {
			wifi_interface=$(basename "$interface_path")
			break
		}
	done
	if [[ -z "$wifi_interface" ]]; then
		log_error "No Wi-Fi interface detected."
		exit 1
	fi
	log_info "Using Wi-Fi interface: $wifi_interface"
	log_info "Connecting to Wi-Fi: $WIFI_SSID"

	local wifi_passphrase
	read -rsp "Enter Wi-Fi passphrase: " wifi_passphrase
	printf '\n'

	iwctl station "$wifi_interface" connect-hidden "$WIFI_SSID" --passphrase "$wifi_passphrase"
	unset wifi_passphrase

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

choose_optional_packages() {
	log_step "Installation options"

	local response
	read -rp "Do you want to install the PHP stack? [y/N]: " response
	[[ "$response" =~ ^[Yy]$ ]] && INSTALL_PHP_STACK=true || INSTALL_PHP_STACK=false
}

select_partitions() {
	log_step "Partition selection"

	log_info "Detected partitions:"
	lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
	printf '\n'

	# Get list of partitions (exclude whole disks, only partitions)
	local -a partitions
	mapfile -t partitions < <(lsblk -lnpo NAME,SIZE,FSTYPE,LABEL | grep -E "^/dev/(nvme[0-9]+n[0-9]+p|sd[a-z]|vd[a-z])[0-9]")

	if [[ ${#partitions[@]} -eq 0 ]]; then
		log_error "No partitions found!"
		exit 1
	fi

	local current_boot_partition current_root_partition
	current_boot_partition=$(blkid -L BOOT 2>/dev/null || true)
	current_root_partition=$(blkid -L Archlinux 2>/dev/null || true)

	local partition_options=()
	local boot_default_index=0
	local root_default_index=0
	local i

	for i in "${!partitions[@]}"; do
		local partition_device="${partitions[$i]%% *}"
		local marker=""
		if [[ "$partition_device" == "$current_boot_partition" ]]; then
			marker=" [current BOOT]"
			boot_default_index=$i
		elif [[ "$partition_device" == "$current_root_partition" ]]; then
			marker=" [current Archlinux]"
			root_default_index=$i
		fi
		partition_options+=("${partitions[$i]}$marker")
	done

	local boot_selected_index root_selected_index

	boot_selected_index=$(select_from_menu "Select BOOT partition" "$boot_default_index" "${partition_options[@]}")
	BOOT_PARTITION="${partitions[$boot_selected_index]%% *}"

	while true; do
		root_selected_index=$(select_from_menu "Select ROOT partition" "$root_default_index" "${partition_options[@]}")
		ROOT_PARTITION="${partitions[$root_selected_index]%% *}"
		[[ "$BOOT_PARTITION" != "$ROOT_PARTITION" ]] && break
		log_warning "BOOT and ROOT cannot be the same partition. Please choose again."
	done

	log_success "Selected: BOOT=$BOOT_PARTITION, ROOT=$ROOT_PARTITION"
}

confirm_and_format_partitions() {
	log_step "Formatting partitions"

	local summary_separator="=============================================="
	local response
	printf '\n'
	printf '%s\n' "$summary_separator"
	printf '%s\n' "           INSTALLATION SUMMARY"
	printf '%s\n' "$summary_separator"
	printf 'Hostname:       %s\n' "$HOSTNAME"
	printf 'Boot Partition: %s\n' "$BOOT_PARTITION"
	printf 'Root Partition: %s\n' "$ROOT_PARTITION"
	printf 'Username:       %s\n' "$USERNAME"
	printf 'Timezone:       %s\n' "$TIMEZONE"
	printf 'Locale:         %s\n' "$LOCALE"
	printf 'Type:           %s\n' "$SYSTEM_DESCRIPTION"
	printf 'PHP stack:      %s\n' "$INSTALL_PHP_STACK"
	printf '%s\n' "$summary_separator"
	printf '\n'

	log_warning "This will ERASE all data on $BOOT_PARTITION and $ROOT_PARTITION!"
	read -rp "Are you sure you want to continue? [y/N]: " response
	[[ "$response" =~ ^[Yy]$ ]] || {
		log_error "Aborted by user"
		exit 1
	}

	[[ -b "$BOOT_PARTITION" && -b "$ROOT_PARTITION" && "$BOOT_PARTITION" != "$ROOT_PARTITION" ]] || {
		log_error "Saved partition selection is no longer valid. Start a new install."
		exit 1
	}

	if mountpoint -q "$TARGET_ROOT"; then
		log_info "Unmounting existing filesystems under $TARGET_ROOT"
		cd /
		if ! umount -R "$TARGET_ROOT"; then
			log_error "Failed to unmount $TARGET_ROOT. Resolve busy mounts and retry."
			exit 1
		fi
	fi

	log_info "Formatting BOOT partition as FAT32"
	mkfs.fat -F32 -n BOOT "$BOOT_PARTITION"

	log_info "Formatting ROOT partition as ext4"
	mkfs.ext4 -F -L Archlinux "$ROOT_PARTITION"

	log_success "Partitions formatted"
}

mount_filesystems() {
	log_step "Mounting filesystems"

	mountpoint -q "$TARGET_ROOT" && cd / && umount -R "$TARGET_ROOT"
	mount -o noatime "$ROOT_PARTITION" "$TARGET_ROOT"
	mount --mkdir -o noatime,umask=0077 "$BOOT_PARTITION" "$TARGET_ROOT/boot"

	# Mount required Work partition so it's available in chroot
	local work_partition
	work_partition=$(blkid -L Work || true)
	if [[ -z "$work_partition" ]]; then
		log_error "Required Work partition (label: Work) not found"
		exit 1
	fi

	mount --mkdir -o noatime "$work_partition" "$TARGET_ROOT/mnt/Work"

	log_success "Filesystems mounted"
}

optimize_mirrors() {
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

configure_live_pacman() {
	log_step "Configuring pacman defaults (live environment)"

	log_info "Enabling ParallelDownloads, Color, ILoveCandy, multilib"
	apply_pacman_defaults /etc/pacman.conf

	log_success "Pacman defaults configured"
}

install_base_system() {
	log_step "Installing base system"

	local packages=("${COMMON_PACKAGES[@]}" "${PROFILE_PACKAGES[@]}")
	if [[ "$INSTALL_PHP_STACK" == true ]]; then
		packages+=("${PHP_PACKAGES[@]}")
	fi

	log_info "Installing ${#packages[@]} packages..."
	pacstrap -K "$TARGET_ROOT" "${packages[@]}"

	log_success "Base system installed"
}

generate_fstab() {
	log_step "Generating fstab"

	genfstab -L "$TARGET_ROOT" >"$TARGET_ROOT/etc/fstab"

	# Auxiliary partitions
	local mount_options="nosuid,nodev,nofail,x-gvfs-show,x-systemd.makedir,noatime"
	local label
	for label in "${AUXILIARY_PARTITION_LABELS[@]}"; do
		blkid -L "$label" &>/dev/null || continue
		local fstab_entry="LABEL=$label  /mnt/$label  ext4  $mount_options  0 2"
		if grep -qE "^[[:space:]]*LABEL=${label}[[:space:]]+" "$TARGET_ROOT/etc/fstab"; then
			log_info "Updating fstab options for $label"
			sed -i "s|^[[:space:]]*LABEL=${label}[[:space:]].*|$fstab_entry|" "$TARGET_ROOT/etc/fstab"
		else
			log_info "Adding $label partition to fstab"
			printf '%s\n' "$fstab_entry" >>"$TARGET_ROOT/etc/fstab"
		fi
	done

	log_success "fstab generated"
}

run_target_configuration() {
	log_step "Preparing chroot"

	install -m 0755 "$RUNTIME_SCRIPT" "$TARGET_ROOT/root/install.sh"

	if [[ -f "$TARGET_ROOT/root/install.state" ]]; then
		log_info "Existing chroot state found; keeping it for resume"
	else
		local live_checkpoint="$NEXT_CHECKPOINT"
		NEXT_CHECKPOINT=""
		save_install_state "$TARGET_ROOT/root/install.state"
		NEXT_CHECKPOINT="$live_checkpoint"
	fi

	# Copy optimized mirrorlist and tune target pacman defaults
	cp /etc/pacman.d/mirrorlist "$TARGET_ROOT/etc/pacman.d/mirrorlist"
	apply_pacman_defaults "$TARGET_ROOT/etc/pacman.conf"
	log_info "Copied mirrorlist and updated target pacman defaults"

	log_info "Entering chroot..."
	arch-chroot "$TARGET_ROOT" /root/install.sh chroot
}

# TARGET SYSTEM STEPS

configure_system_basics() {
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

install_bootloader() {
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
	local kernel_options="root=LABEL=Archlinux rw quiet splash loglevel=3 nowatchdog"

	cat >/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options $kernel_options
EOF

	log_success "Bootloader installed"
}

configure_package_repositories() {
	log_step "Setting up additional repositories and packages"
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

	local packages=("${COMMON_EXTRA_PACKAGES[@]}" "${PROFILE_EXTRA_PACKAGES[@]}")
	log_info "Installing ${#packages[@]} additional packages..."
	pacman -Syu --needed --noconfirm "${packages[@]}"

	log_success "Additional packages installed"
}

configure_zram() {
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

configure_initramfs() {
	log_step "Configuring initramfs"

	install -d /etc/mkinitcpio.conf.d
	cat >/etc/mkinitcpio.conf.d/99-obelisk.conf <<EOF
MODULES=(${PROFILE_INITRAMFS_MODULES[*]})
HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)
EOF

	mkinitcpio -P

	log_success "Initramfs regenerated"
}

enable_system_services() {
	log_step "Enabling services"

	local services=(
		NetworkManager
		systemd-timesyncd
		fstrim.timer
		bluetooth
		ly@tty2
		fwupd-refresh.timer
	)

	services+=("${PROFILE_SERVICES[@]}")

	local service
	for service in "${services[@]}"; do
		log_info "Enabling $service"
		systemctl enable "$service"
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

create_user_account() {
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

bootstrap_user_environment() {
	log_step "Post-install user bootstrap"

	local dotfiles_directory="/mnt/Work/1Progs/Dots"
	local backup_script="$dotfiles_directory/bin/.local/bin/backup-home"
	local stow_packages=(bin kitty quickshell fish nvim mpv "${PROFILE_STOW_PACKAGES[@]}")

	if ! mountpoint -q /mnt/Work; then
		log_info "/mnt/Work is not mounted; attempting mount from fstab..."
		if ! mount --mkdir /mnt/Work; then
			log_error "Failed to mount /mnt/Work. Cannot continue post-user bootstrap."
			return 1
		fi
	fi

	if [[ ! -d "$dotfiles_directory" ]]; then
		log_error "Dots directory not found at $dotfiles_directory."
		return 1
	fi

	if [[ ! -x "$backup_script" ]] || ! run_as_user "\"$backup_script\" -r"; then
		log_warning "backup-home restore failed (or script missing); continuing."
	fi

	run_as_user 'rm -f "$HOME/.bashrc" "$HOME/.bash_profile"'
	run_as_user 'cd "$1" && shift && stow -t "$HOME" "$@"' \
		"$dotfiles_directory" "${stow_packages[@]}"
	run_as_user 'yay -S --needed --noconfirm --removemake --cleanafter antigravity quickshell-git'

	log_success "Post-user bootstrap complete"
}

finish_target_configuration() {
	log_step "Cleanup"

	rm -f /root/install.sh
	clear_install_state

	printf '\n'
	log_success "Installation complete!"
	printf '\n'
	printf '%s\n' "Next steps:"
	printf '%s\n' "  1. Exit chroot (will happen automatically)"
	printf '%s\n' "  2. Script will unmount and reboot"
	printf '\n'
}

# MAIN EXECUTION

reset_install_state() {
	clear_install_state
	NEXT_CHECKPOINT=""
	SYSTEM_PROFILE=""
	HOSTNAME=""
	SYSTEM_DESCRIPTION=""
	INSTALL_PHP_STACK=false
	BOOT_PARTITION=""
	ROOT_PARTITION=""
}

live_main() {
	local banner_separator="========================================"
	printf '\n'
	printf '%s\n' "$banner_separator"
	printf '%s\n' "   Arch Linux Installation Script"
	printf '%s\n' "$banner_separator"
	printf '\n'

	if [[ -f "$INSTALL_STATE_FILE" ]]; then
		if load_install_state; then
			local resume_options=(
				"Resume previous install"
				"Start new install"
			)
			local resume_choice
			resume_choice=$(select_from_menu "Existing install state found" 0 "${resume_options[@]}")
			((resume_choice == 1)) && reset_install_state
		else
			log_warning "Failed to load state file, starting fresh"
			reset_install_state
		fi
	fi

	local -a live_step_functions=(
		detect_system_profile
		ensure_network_connection
		choose_optional_packages
		select_partitions
		confirm_and_format_partitions
		mount_filesystems
		optimize_mirrors
		configure_live_pacman
		install_base_system
		generate_fstab
		run_target_configuration
	)
	run_resumable_steps "${live_step_functions[@]}"

	log_info "Target system configuration completed successfully"
	clear_install_state
	printf '\n'
	read -rsn1 -p "Press any key to unmount and reboot (Ctrl+C to cancel)..."
	printf '\n'

	if umount -R "$TARGET_ROOT" 2>/dev/null; then
		log_success "Unmounted $TARGET_ROOT"
	else
		log_warning "Failed to unmount $TARGET_ROOT cleanly; rebooting anyway."
	fi

	log_success "Ready to reboot"
	sleep 2
	reboot
}

target_main() {
	INSTALL_STATE_FILE="/root/install.state"
	load_install_state || {
		log_error "Missing or invalid chroot installation state"
		return 1
	}

	local -a target_step_functions=(
		configure_system_basics
		install_bootloader
		configure_package_repositories
		configure_zram
		configure_initramfs
		enable_system_services
		create_user_account
		bootstrap_user_environment
	)
	run_resumable_steps "${target_step_functions[@]}"
	finish_target_configuration
}

self_check() {
	local self_check_dir
	self_check_dir=$(mktemp -d)
	trap 'rm -rf -- "$self_check_dir"' EXIT

	SYSTEM_PROFILE=wolverine
	apply_system_profile
	[[ "$HOSTNAME" == Wolverine ]]
	[[ "$SYSTEM_DESCRIPTION" == "PC (AMD + NVIDIA)" ]]
	[[ "${PROFILE_PACKAGES[*]}" == "${WOLVERINE_PACKAGES[*]}" ]]
	[[ "${PROFILE_EXTRA_PACKAGES[*]}" == "${WOLVERINE_EXTRA_PACKAGES[*]}" ]]
	[[ "${PROFILE_SERVICES[*]}" == nvidia-persistenced ]]
	[[ "${PROFILE_STOW_PACKAGES[*]}" == hypr ]]
	((${#PROFILE_INITRAMFS_MODULES[@]} == 4))

	SYSTEM_PROFILE=mentalist
	apply_system_profile
	[[ "$HOSTNAME" == Mentalist ]]
	[[ "$SYSTEM_DESCRIPTION" == "Laptop (Intel)" ]]
	[[ "${PROFILE_PACKAGES[*]}" == "${MENTALIST_PACKAGES[*]}" ]]
	[[ "${PROFILE_EXTRA_PACKAGES[*]}" == "${MENTALIST_EXTRA_PACKAGES[*]}" ]]
	[[ "${PROFILE_SERVICES[*]}" == asusd ]]
	[[ "${PROFILE_STOW_PACKAGES[*]}" == niri ]]
	((${#PROFILE_INITRAMFS_MODULES[@]} == 0))

	local original_state_file="$INSTALL_STATE_FILE"
	local original_umask state_file
	original_umask=$(umask)
	state_file="$self_check_dir/install.state"
	INSTALL_STATE_FILE="$state_file"
	NEXT_CHECKPOINT=enable_system_services
	BOOT_PARTITION=/dev/example1
	ROOT_PARTITION=/dev/example2
	INSTALL_PHP_STACK=true
	save_install_state
	[[ "$(umask)" == "$original_umask" ]]
	[[ "$(stat -c '%a' "$INSTALL_STATE_FILE")" == 600 ]]
	NEXT_CHECKPOINT="" SYSTEM_PROFILE="" BOOT_PARTITION="" ROOT_PARTITION="" INSTALL_PHP_STACK=false
	load_install_state
	[[ "$NEXT_CHECKPOINT" == enable_system_services ]]
	[[ "$SYSTEM_PROFILE" == mentalist ]]
	[[ "$BOOT_PARTITION" == /dev/example1 ]]
	[[ "$ROOT_PARTITION" == /dev/example2 ]]
	[[ "$INSTALL_PHP_STACK" == true ]]

	# Invalid state must be rejected without partially replacing the current plan.
	printf '%s\n' enable_system_services mentalist /dev/example1 /dev/example2 maybe >"$INSTALL_STATE_FILE"
	if load_install_state; then
		log_error "Self-check accepted an invalid state boolean"
		return 1
	fi
	[[ "$NEXT_CHECKPOINT" == enable_system_services ]]
	[[ "$SYSTEM_PROFILE" == mentalist ]]
	[[ "$INSTALL_PHP_STACK" == true ]]

	printf '%s\n' enable_system_services unknown /dev/example1 /dev/example2 true >"$INSTALL_STATE_FILE"
	if load_install_state; then
		log_error "Self-check accepted an unknown profile"
		return 1
	fi
	[[ "$SYSTEM_PROFILE" == mentalist ]]

	printf '%s\n' enable_system_services mentalist /dev/example1 /dev/example2 >"$INSTALL_STATE_FILE"
	if load_install_state; then
		log_error "Self-check accepted a truncated state file"
		return 1
	fi

	local state_target="$self_check_dir/state-target"
	printf '%s\n' enable_system_services mentalist /dev/example1 /dev/example2 true >"$state_target"
	rm -f "$INSTALL_STATE_FILE"
	ln -s "$state_target" "$INSTALL_STATE_FILE"
	if load_install_state; then
		log_error "Self-check accepted a symlinked state file"
		return 1
	fi
	rm -f "$INSTALL_STATE_FILE"

	# Exercise the runner with observable fake steps, not true/false placeholders.
	local step_log="$self_check_dir/steps.log"
	_self_check_step_one() { printf '%s\n' one >>"$step_log"; }
	_self_check_step_two() { printf '%s\n' two >>"$step_log"; }
	_self_check_step_three() { printf '%s\n' three >>"$step_log"; }
	_self_check_step_fail() {
		printf '%s\n' fail >>"$step_log"
		return 1
	}

	SYSTEM_PROFILE=mentalist
	apply_system_profile
	BOOT_PARTITION=/dev/example1
	ROOT_PARTITION=/dev/example2
	INSTALL_PHP_STACK=true
	NEXT_CHECKPOINT=""
	: >"$step_log"
	run_resumable_steps _self_check_step_one _self_check_step_two _self_check_step_three
	[[ "$(<"$step_log")" == $'one\ntwo\nthree' ]]
	[[ "$NEXT_CHECKPOINT" == "$INSTALL_COMPLETE_MARKER" ]]

	NEXT_CHECKPOINT=_self_check_step_two
	: >"$step_log"
	run_resumable_steps _self_check_step_one _self_check_step_two _self_check_step_three
	[[ "$(<"$step_log")" == $'two\nthree' ]]
	[[ "$NEXT_CHECKPOINT" == "$INSTALL_COMPLETE_MARKER" ]]

	NEXT_CHECKPOINT="$INSTALL_COMPLETE_MARKER"
	: >"$step_log"
	run_resumable_steps _self_check_step_one
	[[ ! -s "$step_log" ]]

	NEXT_CHECKPOINT=missing_step
	if run_resumable_steps _self_check_step_one >"$self_check_dir/unknown-checkpoint.log"; then
		log_error "Self-check accepted an unknown checkpoint"
		return 1
	fi
	[[ ! -s "$step_log" ]]

	# A failed step must leave its checkpoint persisted and must not run later steps.
	NEXT_CHECKPOINT=""
	: >"$step_log"
	local failure_status
	set +e
	(
		trap - ERR
		set -e
		run_resumable_steps _self_check_step_one _self_check_step_fail _self_check_step_three
	)
	failure_status=$?
	set -e
	((failure_status != 0))
	[[ "$(<"$step_log")" == $'one\nfail' ]]
	local -a failed_state
	mapfile -t failed_state <"$INSTALL_STATE_FILE"
	[[ "${failed_state[0]}" == _self_check_step_fail ]]

	# Pacman edits must be complete and idempotent.
	local pacman_fixture="$self_check_dir/pacman.conf"
	cat >"$pacman_fixture" <<'EOF'
[options]
#Color
#ParallelDownloads = 5

#[multilib]
#Include = /etc/pacman.d/mirrorlist
EOF
	apply_pacman_defaults "$pacman_fixture"
	cp "$pacman_fixture" "$self_check_dir/pacman.expected"
	apply_pacman_defaults "$pacman_fixture"
	cmp -s "$pacman_fixture" "$self_check_dir/pacman.expected"
	grep -qx Color "$pacman_fixture"
	grep -qx 'ParallelDownloads = 5' "$pacman_fixture"
	grep -qx '\[multilib\]' "$pacman_fixture"
	grep -qx 'Include = /etc/pacman.d/mirrorlist' "$pacman_fixture"
	[[ "$(grep -c '^ILoveCandy$' "$pacman_fixture")" == 1 ]]

	INSTALL_STATE_FILE="$original_state_file"
	rm -rf -- "$self_check_dir"
	trap - EXIT
	log_success "Self-check passed"
}

if [[ "${1:-}" == "chroot" ]]; then
	target_main
elif [[ "${1:-}" == "--self-check" ]]; then
	self_check
else
	live_main
fi
