# Arch Linux Installation Log  
Hardware: Ryzen 5900X • RTX 3080 • NVMe

## 0  Boot environment
- Boot Arch ISO, open live shell.
- Connect to hidden Wi-Fi  
    iwctl station wlan0 connect-hidden Ghuzlan-private --passphrase Khghza12345

## 1  Pre-install tweaks
- /etc/pacman.conf → enable  
    ParallelDownloads = 5

## 2  Disk layout (nvme0n1)
- Keep GPT layout  
  - p1  1 GiB  EFI System  
  - p2  237 GiB root
- Format & label  
    mkfs.fat -F32 -n EFI /dev/nvme0n1p1  
    mkfs.ext4 -L Archlinux /dev/nvme0n1p2

## 3  Mount
    mount /dev/nvme0n1p2 /mnt
    mkdir /mnt/boot
    mount /dev/nvme0n1p1 /mnt/boot

## 4  Mirrorlist
- Edit /etc/pacman.d/mirrorlist with vim; move Egypt/near mirrors to top.

## 5  Base install
    pacstrap /mnt base linux linux-firmware vim

## 6  fstab
    genfstab -U /mnt >> /mnt/etc/fstab
- In fstab: for /boot change to  
    fmask=0077,dmask=0077

## 7  Chroot
    arch-chroot /mnt

## 8  System basics
    ln -sf /usr/share/zoneinfo/Africa/Cairo /etc/localtime
    hwclock --systohc
    vim /etc/locale.gen      # uncomment en_US.UTF-8
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "archbox" > /etc/hostname
    printf "127.0.0.1\tlocalhost\n127.0.1.1\tarchbox.localdomain archbox\n" >> /etc/hosts
    passwd                   # set root pwd

## 9  systemd-boot
    bootctl install
- /boot/loader/entries/arch.conf  
    title   Arch Linux  
    linux   /vmlinuz-linux  
    initrd  /amd-ucode.img  
    initrd  /initramfs-linux.img  
    options root=LABEL=Archlinux rw quiet splash loglevel=3 nowatchdog \
            nvidia-drm.modeset=1 vt.global_cursor_default=0

## 10  Microcode & GPU
    pacman -S amd-ucode
    pacman -S nvidia-open nvidia-open-dkms nvidia-utils lib32-nvidia-utils

## 11  Swap file (4 GiB)
    dd if=/dev/zero of=/swap bs=1M count=4096 status=progress
    chmod 600 /swap
    mkswap /swap
    swapon /swap
    echo '/swap none swap defaults 0 0' >> /etc/fstab

## 12  Plymouth
- Install  
    pacman -S plymouth
- /etc/mkinitcpio.conf  
    MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)  
    HOOKS=(base plymouth udev autodetect modconf block filesystems fsck)
- Regenerate  
    mkinitcpio -P

## 13  Wireless regulatory DB
    pacman -S wireless-regdb

## 14  Services
    systemctl enable NetworkManager
    systemctl enable systemd-timesyncd
    systemctl enable fstrim.timer
    systemctl enable bluetooth
    systemctl enable power-profiles-daemon
    systemctl enable sshd            # optional, enabled here

## 15  User
    useradd -m -c "Anas Khalifa" \
      -G wheel,audio,video,network,storage,lp,sys,rfkill,bluetooth,users anas
    passwd anas
    EDITOR=vim visudo        # uncomment '%wheel ALL=(ALL:ALL) ALL'

## 16  Exit & reboot
    exit
    umount -R /mnt           # use 'umount -l /mnt' if busy
    reboot
# Remove installation media; boot into fresh Arch with Plymouth splash.
