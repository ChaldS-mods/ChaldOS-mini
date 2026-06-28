#!/bin/bash
# ChaldOS Installer
# ===================
# Installs ChaldOS to disk with options:
#   1) Use entire disk
#   2) Install alongside another OS (dual-boot)
#   3) Manual partitioning
#
# Usage:
#   ./install-chaldos.sh              — Interactive installer
#   ./install-chaldos.sh --auto <dev> — Automatic, use entire disk
#   ./install-chaldos.sh --help       — Show help

set -euo pipefail

VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
header() { echo -e "\n${CYAN}═══ $1 ═══${NC}\n"; }

# Source installer library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[[ -f "${SCRIPT_DIR}/install-libs.sh" ]] && source "${SCRIPT_DIR}/install-libs.sh"

# ============================================================
# DETECT SYSTEM
# ============================================================
detect_system() {
    header "Detecting System"

    # Check we're root
    [[ $EUID -eq 0 ]] || error "Installer must be run as root"

    # Detect OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log "Detected OS: ${NAME} ${VERSION_ID}"
    else
        warn "Cannot detect OS — assuming clean install"
    fi

    # Detect disks
    echo ""
    echo "Available disks:"
    echo "────────────────────────────────────────────"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL 2>/dev/null | head -20 || \
        fdisk -l 2>/dev/null | grep '^Disk /' || \
        echo "Cannot list disks"

    # Detect other OS installations (for dual-boot)
    detect_other_os
}

detect_other_os() {
    OTHER_OS=()
    echo ""
    echo "Detecting other operating systems..."

    # Check EFI partitions for Windows
    if command -v efibootmgr &>/dev/null; then
        efibootmgr -v 2>/dev/null | grep -i "Windows" && {
            OTHER_OS+=("Windows")
            log "Windows detected (EFI boot entry)"
        } || true
    fi

    # Check common mount points
    for dev in /dev/sd* /dev/nvme*n*; do
        [[ -b "$dev" ]] || continue
        local tmp_mnt=$(mktemp -d)
        if mount "$dev" "$tmp_mnt" 2>/dev/null; then
            if [[ -f "${tmp_mnt}/Windows/System32/winload.exe" ]]; then
                OTHER_OS+=("Windows")
                log "Windows detected on $dev"
            fi
            if [[ -f "${tmp_mnt}/etc/os-release" ]]; then
                source "${tmp_mnt}/etc/os-release" 2>/dev/null || true
                OTHER_OS+=("${NAME:-Linux}")
                log "${NAME:-Linux} detected on $dev"
            fi
            umount "$tmp_mnt" 2>/dev/null || true
        fi
        rmdir "$tmp_mnt" 2>/dev/null || true
    done

    if [[ ${#OTHER_OS[@]} -eq 0 ]]; then
        warn "No other operating systems found"
    fi
}

# ============================================================
# DISK SELECTION
# ============================================================
select_disk() {
    header "Select Installation Disk"

    local disks=()
    while IFS= read -r line; do
        disks+=("$line")
    done < <(lsblk -nd -o NAME,SIZE,TYPE,MODEL 2>/dev/null | grep disk || \
             fdisk -l 2>/dev/null | grep '^Disk /' | sed 's/Disk //;s/: /=/')

    if [[ ${#disks[@]} -eq 0 ]]; then
        error "No disks found!"
    fi

    echo "Select target disk:"
    local i=1
    for disk in "${disks[@]}"; do
        echo "  ${i}) ${disk}"
        i=$((i + 1))
    done

    echo ""
    read -p "Enter number (1-${#disks[@]}): " choice

    [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#disks[@]}" ]] || \
        error "Invalid selection"

    local selected="${disks[$((choice - 1))]}"
    TARGET_DISK="/dev/$(echo "$selected" | awk '{print $1}')"

    log "Selected: $TARGET_DISK"
    echo ""
    warn "WARNING: All data on $TARGET_DISK will be erased!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    [[ "$confirm" = "yes" ]] || error "Installation cancelled"
}

# ============================================================
# INSTALLATION TYPE
# ============================================================
select_install_type() {
    header "Installation Type"

    echo "Select installation type:"
    echo "  1) Use entire disk — Wipes the disk and installs ChaldOS"
    echo "  2) Install alongside another OS — Creates dual-boot"

    if [[ ${#OTHER_OS[@]} -gt 0 ]]; then
        echo -e "${GREEN}     Other OS detected: ${OTHER_OS[*]}${NC}"
    fi

    echo "  3) Manual partitioning — Advanced users only"
    echo ""
    read -p "Enter choice (1-3): " INSTALL_TYPE

    case "$INSTALL_TYPE" in
        1) INSTALL_MODE="entire-disk" ;;
        2) INSTALL_MODE="dual-boot" ;;
        3) INSTALL_MODE="manual" ;;
        *) error "Invalid selection" ;;
    esac
}

# ============================================================
# PARTITIONING
# ============================================================
partition_disk() {
    header "Partitioning Disk: $TARGET_DISK"

    case "$INSTALL_MODE" in
        entire-disk)
            partition_entire_disk
            ;;
        dual-boot)
            partition_dual_boot
            ;;
        manual)
            partition_manual
            ;;
    esac
}

partition_entire_disk() {
    log "Creating partitions on $TARGET_DISK..."

    # Determine if EFI or BIOS
    if [[ -d /sys/firmware/efi ]]; then
        # EFI: GPT partition table
        log "EFI system detected — using GPT"
        parted -s "$TARGET_DISK" mklabel gpt
        parted -s "$TARGET_DISK" mkpart primary fat32 1MiB 512MiB
        parted -s "$TARGET_DISK" set 1 esp on
        parted -s "$TARGET_DISK" mkpart primary ext4 512MiB 100%

        BOOT_PART="${TARGET_DISK}1"
        ROOT_PART="${TARGET_DISK}2"

        # Format
        log "Formatting EFI partition..."
        mkfs.fat -F32 "$BOOT_PART"
        log "Formatting root partition..."
        mkfs.ext4 -F -L "CHALDOS" "$ROOT_PART"
    else
        # BIOS: MBR partition table
        log "BIOS system detected — using MBR"
        parted -s "$TARGET_DISK" mklabel msdos
        parted -s "$TARGET_DISK" mkpart primary ext4 1MiB 100%
        parted -s "$TARGET_DISK" set 1 boot on

        ROOT_PART="${TARGET_DISK}1"
        BOOT_PART=""

        # Format
        log "Formatting root partition..."
        mkfs.ext4 -F -L "CHALDOS" "$ROOT_PART"
    fi
}

partition_dual_boot() {
    log "Setting up dual-boot..."

    # Shrink existing partition and create space for ChaldOS
    warn "Dual-boot requires free space on disk."
    warn "Make sure you have at least 10GB free."

    read -p "Continue with dual-boot setup? (yes/no): " confirm
    [[ "$confirm" = "yes" ]] || error "Dual-boot cancelled"

    # Try to shrink the last partition
    local last_part=$(parted -s "$TARGET_DISK" print | tail -2 | grep -v '^$' | head -1 | awk '{print $1}')

    if [[ -n "$last_part" ]]; then
        log "Attempting to shrink partition $last_part..."
        # Note: resizing requires the partition to be unmounted
        # This is a simplified approach — real installer would use resize2fs
        warn "Automatic partition resizing is experimental."
        warn "Please manually shrink your existing partition and run the installer again."
        log "Alternative: Use 'Manual partitioning' option."
        partition_manual
    else
        partition_manual
    fi
}

partition_manual() {
    log "Manual partitioning selected."
    echo ""
    echo "Available partitions:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$TARGET_DISK" 2>/dev/null || \
        fdisk -l "$TARGET_DISK"

    echo ""
    echo "Would you like to:"
    echo "  1) Open fdisk/cfdisk to manually partition"
    echo "  2) Use an existing partition"
    echo "  3) Go back"
    read -p "Enter choice (1-3): " manual_choice

    case "$manual_choice" in
        1)
            if command -v cfdisk &>/dev/null; then
                cfdisk "$TARGET_DISK"
            elif command -v fdisk &>/dev/null; then
                fdisk "$TARGET_DISK"
            else
                error "No partitioning tool found"
            fi
            # After manual partitioning, ask for root partition
            echo ""
            lsblk "$TARGET_DISK"
            read -p "Enter root partition (e.g., ${TARGET_DISK}2): " ROOT_PART
            ;;
        2)
            read -p "Enter existing root partition: " ROOT_PART
            warn "This will FORMAT $ROOT_PART!"
            read -p "Format $ROOT_PART? (yes/no): " fmt_confirm
            [[ "$fmt_confirm" = "yes" ]] && mkfs.ext4 -F -L "CHALDOS" "$ROOT_PART"
            ;;
        3)
            select_install_type
            partition_disk
            return
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
}

# ============================================================
# INSTALL SYSTEM
# ============================================================
install_system() {
    header "Installing ChaldOS"

    local mount_point="/mnt/chaldos"
    mkdir -p "$mount_point"

    # Mount root
    mount "$ROOT_PART" "$mount_point"
    log "Mounted $ROOT_PART on $mount_point"

    # Mount EFI partition if applicable
    if [[ -n "${BOOT_PART:-}" ]]; then
        mkdir -p "${mount_point}/boot/efi"
        mount "$BOOT_PART" "${mount_point}/boot/efi"
        log "Mounted EFI partition"
    fi

    # Copy rootfs
    log "Copying root filesystem..."
    if [[ -d "${SCRIPT_DIR}/../rootfs" ]]; then
        rsync -aHAX "${SCRIPT_DIR}/../rootfs/" "$mount_point/" 2>/dev/null || \
            cp -a "${SCRIPT_DIR}/../rootfs/"* "$mount_point/"
    else
        error "Root filesystem not found at ${SCRIPT_DIR}/../rootfs"
    fi

    # Copy kernel and initramfs
    if [[ -f "${SCRIPT_DIR}/../output/images/vmlinuz" ]]; then
        mkdir -p "$mount_point/boot"
        cp "${SCRIPT_DIR}/../output/images/vmlinuz" "$mount_point/boot/"
        cp "${SCRIPT_DIR}/../output/images/initramfs.cpio.gz" "$mount_point/boot/"
        log "Kernel and initramfs installed"
    else
        warn "Kernel not pre-built — will need to compile on first boot"
    fi

    # Create mount points
    mkdir -p "$mount_point"/{proc,sys,dev,run,tmp}

    # Set permissions
    chmod 755 "$mount_point"
    chmod 1777 "$mount_point/tmp"
    chmod 1777 "$mount_point/dev/shm" 2>/dev/null || true
}

# ============================================================
# BOOTLOADER INSTALLATION
# ============================================================
install_bootloader() {
    header "Installing Bootloader"

    local mount_point="/mnt/chaldos"

    # Mount pseudo-filesystems for chroot
    mount --bind /dev "${mount_point}/dev"
    mount --bind /proc "${mount_point}/proc"
    mount --bind /sys "${mount_point}/sys"

    if [[ -d /sys/firmware/efi ]]; then
        log "Installing GRUB for EFI..."
        chroot "$mount_point" /bin/bash -c "
            grub-install --target=x86_64-efi \
                --efi-directory=/boot/efi \
                --boot-directory=/boot \
                --recheck --no-floppy
            grub-mkconfig -o /boot/grub/grub.cfg
        " 2>/dev/null || {
            warn "GRUB EFI installation failed. Installing manually."
            cp -r "${SCRIPT_DIR}/../bootloader/grub/"* "$mount_point/boot/grub/" 2>/dev/null || true
        }
    else
        log "Installing GRUB for BIOS..."
        chroot "$mount_point" /bin/bash -c "
            grub-install --target=i386-pc \
                --boot-directory=/boot \
                --recheck --no-floppy $TARGET_DISK
            grub-mkconfig -o /boot/grub/grub.cfg
        " 2>/dev/null || {
            warn "GRUB BIOS installation failed. Installing config manually."
            cp -r "${SCRIPT_DIR}/../bootloader/grub/"* "$mount_point/boot/grub/" 2>/dev/null || true
        }
    fi

    # Clean up mounts
    umount "${mount_point}/dev" 2>/dev/null || true
    umount "${mount_point}/proc" 2>/dev/null || true
    umount "${mount_point}/sys" 2>/dev/null || true

    log "Bootloader installed"
}

# ============================================================
# POST-INSTALL
# ============================================================
post_install() {
    header "Post-Installation Setup"

    local mount_point="/mnt/chaldos"

    # Create fstab
    local root_uuid=$(blkid -s UUID -o value "$ROOT_PART" 2>/dev/null || echo "")
    if [[ -n "$root_uuid" ]]; then
        echo "# ChaldOS fstab" > "${mount_point}/etc/fstab"
        echo "UUID=${root_uuid} / ext4 defaults,noatime 0 1" >> "${mount_point}/etc/fstab"
    fi

    if [[ -n "${BOOT_PART:-}" ]]; then
        local boot_uuid=$(blkid -s UUID -o value "$BOOT_PART" 2>/dev/null || echo "")
        if [[ -n "$boot_uuid" ]]; then
            echo "UUID=${boot_uuid} /boot/efi vfat defaults 0 2" >> "${mount_point}/etc/fstab"
        fi
    fi

    # Standard fstab entries
    echo "proc /proc proc defaults 0 0" >> "${mount_point}/etc/fstab"
    echo "sysfs /sys sysfs defaults 0 0" >> "${mount_point}/etc/fstab"
    echo "tmpfs /tmp tmpfs defaults 0 0" >> "${mount_point}/etc/fstab"

    # Set hostname
    echo "chaldos" > "${mount_point}/etc/hostname"

    # Set root password
    chroot "$mount_point" /bin/bash -c "echo 'root:chaldos' | chpasswd" 2>/dev/null || \
        warn "Could not set root password (set manually: passwd)"

    log "Post-installation complete"
}

# ============================================================
# FINISH
# ============================================================
finish_install() {
    header "Installation Complete"

    local mount_point="/mnt/chaldos"

    # Unmount
    umount "${mount_point}/boot/efi" 2>/dev/null || true
    umount "$mount_point" 2>/dev/null || true

    # Remove mount point
    rmdir "$mount_point" 2>/dev/null || true

    echo ""
    echo "ChaldOS v${VERSION} has been installed successfully!"
    echo ""
    echo "  Installation: $INSTALL_MODE"
    echo "  Target disk:  $TARGET_DISK"
    echo "  Root:         $ROOT_PART"
    echo ""
    echo "Reboot and remove the installation media to boot into ChaldOS."
    echo ""
    echo "Default credentials:"
    echo "  Username: root"
    echo "  Password: chaldos"
    echo ""
    read -p "Reboot now? (y/N): " reboot_now
    if [[ "$reboot_now" =~ ^[Yy] ]]; then
        log "Rebooting..."
        reboot
    fi
}

# ============================================================
# MAIN
# ============================================================
main() {
    # Handle auto-install
    if [[ "${1:-}" = "--auto" ]] && [[ -n "${2:-}" ]]; then
        TARGET_DISK="$2"
        INSTALL_MODE="entire-disk"
        [[ $EUID -eq 0 ]] || error "Must be root"

        # Determine partition names
        if [[ -d /sys/firmware/efi ]]; then
            BOOT_PART="${TARGET_DISK}1"
            ROOT_PART="${TARGET_DISK}2"
        else
            BOOT_PART=""
            ROOT_PART="${TARGET_DISK}1"
        fi

        partition_entire_disk
        install_system
        install_bootloader
        post_install
        finish_install
        return
    fi

    # Help
    if [[ "${1:-}" = "--help" ]] || [[ "${1:-}" = "-h" ]]; then
        echo "ChaldOS Installer v${VERSION}"
        echo ""
        echo "Usage:"
        echo "  sudo ./install-chaldos.sh              Interactive install"
        echo "  sudo ./install-chaldos.sh --auto <dev>  Automatic install"
        echo ""
        exit 0
    fi

    # Interactive install
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║         ChaldOS Installer v${VERSION}              ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""

    detect_system
    select_disk
    select_install_type
    partition_disk
    install_system
    install_bootloader
    post_install
    finish_install
}

main "$@"
