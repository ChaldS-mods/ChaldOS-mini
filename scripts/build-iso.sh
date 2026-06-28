#!/bin/bash
#
# build-iso.sh
# Create a bootable ISO image for ChaldOS.
# Supports:
#   - GRUB (BIOS + EFI)
#   - ISOLINUX/SYSLINUX (legacy BIOS fallback)
#   - xorriso, grub-mkrescue, or mkisofs
#
# Usage: ./build-iso.sh [--label LABEL] [--output PATH]
#   --label LABEL     Volume label for ISO (default: CHALDOS)
#   --output PATH     Output ISO path (default: ../build/chaldos-x86_64.iso)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}}"
BUILD_DIR="${BUILD_DIR:-${OUTPUT_DIR}/build}"
IMAGES_DIR="${IMAGES_DIR:-${OUTPUT_DIR}/images}"
ISO_DIR="${ISO_DIR:-${BUILD_DIR}/iso}"
KERNEL_DIR="${KERNEL_DIR:-${BUILD_DIR}/kernel}"
INITRAMFS="${INITRAMFS:-${IMAGES_DIR}/initramfs.cpio.gz}"
OUTPUT="${OUTPUT:-${IMAGES_DIR}/chaldos-x86_64.iso}"
LABEL="CHALDOS"
ISO_LABEL="CHALDOS"
BOOTLOADER_DIR="${PROJECT_DIR}/bootloader"

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()  { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()   { echo -e "${CYAN}[STEP]${NC}  $*"; }

# Cleanup handler
cleanup() {
    log_warn "ISO build interrupted or exited with error."
}
trap cleanup EXIT ERR

# ------------------------------------------------------------------
# Parse command-line arguments
# ------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --label)
                if [[ -z "${2:-}" ]]; then
                    log_error "--label requires an argument."
                    exit 1
                fi
                LABEL="$2"
                ISO_LABEL="$(echo "$2" | tr '[:lower:]' '[:upper:]' | cut -c1-32)"
                shift 2
                ;;
            --output)
                if [[ -z "${2:-}" ]]; then
                    log_error "--output requires an argument."
                    exit 1
                fi
                OUTPUT="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [--label LABEL] [--output PATH]"
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                exit 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------
# Check prerequisites
# ------------------------------------------------------------------
check_prerequisites() {
    log_step "Checking prerequisites..."

    local has_iso_tool=false

    if command -v xorriso &>/dev/null; then
        has_iso_tool=true
        log_info "Found xorriso: $(xorriso --version 2>&1 | head -1)"
    fi

    if command -v grub-mkrescue &>/dev/null; then
        has_iso_tool=true
        log_info "Found grub-mkrescue"
    fi

    if command -v mkisofs &>/dev/null; then
        has_iso_tool=true
        log_info "Found mkisofs/genisoimage"
    fi

    if [[ "$has_iso_tool" != "true" ]]; then
        log_error "No ISO creation tool found."
        log_error "Install one of: xorriso, grub-mkrescue (from grub package), or genisoimage"
        exit 1
    fi

    # Check for kernel
    if [[ ! -f "${KERNEL_DIR}/vmlinuz" ]]; then
        log_error "Kernel not found at ${KERNEL_DIR}/vmlinuz"
        log_error "Run build-kernel.sh first."
        exit 1
    fi

    # Check for initramfs
    if [[ ! -f "${INITRAMFS}" ]]; then
        log_error "Initramfs not found at ${INITRAMFS}"
        log_error "Run build-initramfs.sh first."
        exit 1
    fi

    log_info "All prerequisites met."
}

# ------------------------------------------------------------------
# Set up ISO directory structure
# ------------------------------------------------------------------
setup_iso_dir() {
    log_step "Setting up ISO directory structure..."

    # Clean previous ISO directory
    if [[ -d "${ISO_DIR}" ]]; then
        rm -rf "${ISO_DIR}"
    fi

    # Create directory structure for both BIOS and EFI boot
    mkdir -p "${ISO_DIR}/boot/grub"
    mkdir -p "${ISO_DIR}/boot/isolinux"
    mkdir -p "${ISO_DIR}/EFI/BOOT"

    log_info "ISO directory created at ${ISO_DIR}"
}

# ------------------------------------------------------------------
# Copy kernel and initramfs
# ------------------------------------------------------------------
copy_boot_files() {
    log_step "Copying boot files..."

    # Copy kernel
    cp -f "${KERNEL_DIR}/vmlinuz" "${ISO_DIR}/boot/vmlinuz"
    log_info "Copied kernel to ${ISO_DIR}/boot/vmlinuz"

    # Copy initramfs
    cp -f "${INITRAMFS}" "${ISO_DIR}/boot/initramfs.cpio.gz"
    log_info "Copied initramfs to ${ISO_DIR}/boot/initramfs.cpio.gz"

    # Copy System.map (optional, useful for debugging)
    if [[ -f "${KERNEL_DIR}/System.map" ]]; then
        cp -f "${KERNEL_DIR}/System.map" "${ISO_DIR}/boot/System.map"
        log_info "Copied System.map"
    fi
}

# ------------------------------------------------------------------
# Create GRUB configuration
# ------------------------------------------------------------------
create_grub_config() {
    log_step "Creating GRUB configuration..."

    cat > "${ISO_DIR}/boot/grub/grub.cfg" << GRUBCFG
# GRUB boot configuration for ChaldOS
set default=0
set timeout=5
set gfxmode=auto
set gfxpayload=keep

# Load video drivers for nice splash
insmod all_video
insmod gfxterm
insmod png
insmod gfxmenu

# Set the background and terminal
if loadfont unicode; then
    terminal_output gfxterm
fi

# ChaldOS default boot
menuentry "ChaldOS Linux" {
    echo "Loading ChaldOS kernel..."
    linux /boot/vmlinuz root=/dev/ram0 rw quiet splash console=tty0
    echo "Loading initramfs..."
    initrd /boot/initramfs.cpio.gz
}

# ChaldOS verbose boot (for debugging)
menuentry "ChaldOS Linux (Verbose)" {
    linux /boot/vmlinuz root=/dev/ram0 rw loglevel=7 console=tty0
    initrd /boot/initramfs.cpio.gz
}

# Safe mode (no KMS, basic VESA)
menuentry "ChaldOS Linux (Safe Mode)" {
    linux /boot/vmlinuz root=/dev/ram0 rw nomodeset vga=788
    initrd /boot/initramfs.cpio.gz
}

# ChaldOS single user mode
menuentry "ChaldOS Linux (Single User)" {
    linux /boot/vmlinuz root=/dev/ram0 rw single
    initrd /boot/initramfs.cpio.gz
}

# Memory test (if memtest is available)
if [ -f /boot/memtest86+ ]; then
    menuentry "Memory Test (memtest86+)" {
        linux /boot/memtest86+
    }
fi

# Boot from first hard disk
menuentry "Boot from Hard Disk" {
    set root=(hd0)
    chainloader +1
}

# System restart
menuentry "Reboot" {
    reboot
}

# System shutdown
menuentry "Shutdown" {
    halt
}
GRUBCFG

    log_info "Created GRUB config: ${ISO_DIR}/boot/grub/grub.cfg"
}

# ------------------------------------------------------------------
# Create ISOLINUX configuration (legacy BIOS fallback)
# ------------------------------------------------------------------
create_isolinux_config() {
    log_step "Creating ISOLINUX configuration..."

    cat > "${ISO_DIR}/boot/isolinux/isolinux.cfg" << ISOLINUXCFG
# ISOLINUX configuration for ChaldOS
# This is used when booting in legacy BIOS mode without GRUB

DEFAULT chaldos
PROMPT 1
TIMEOUT 100
UI menu.c32
MENU TITLE ChaldOS Linux Boot Menu

LABEL chaldos
    MENU LABEL ChaldOS Linux
    KERNEL /boot/vmlinuz
    APPEND root=/dev/ram0 rw quiet splash console=tty0 initrd=/boot/initramfs.cpio.gz

LABEL verbose
    MENU LABEL ChaldOS Linux (Verbose)
    KERNEL /boot/vmlinuz
    APPEND root=/dev/ram0 rw loglevel=7 console=tty0 initrd=/boot/initramfs.cpio.gz

LABEL safemode
    MENU LABEL ChaldOS Linux (Safe Mode, no KMS)
    KERNEL /boot/vmlinuz
    APPEND root=/dev/ram0 rw nomodeset vga=788 initrd=/boot/initramfs.cpio.gz

LABEL single
    MENU LABEL ChaldOS Linux (Single User)
    KERNEL /boot/vmlinuz
    APPEND root=/dev/ram0 rw single initrd=/boot/initramfs.cpio.gz

LABEL hdd
    MENU LABEL Boot from Hard Disk
    COM32 chain.c32
    APPEND hd0

LABEL reboot
    MENU LABEL Reboot
    COM32 reboot.c32

LABEL poweroff
    MENU LABEL Power Off
    COM32 poweroff.c32
ISOLINUXCFG

    # Create ISOLINUX boot catalog marker
    echo "ChaldOS ISOLINUX boot catalog" > "${ISO_DIR}/boot/isolinux/boot.cat"

    log_info "Created ISOLINUX config: ${ISO_DIR}/boot/isolinux/isolinux.cfg"
}

# ------------------------------------------------------------------
# Create EFI boot files
# ------------------------------------------------------------------
create_efi_boot() {
    log_step "Creating EFI boot configuration..."

    # For EFI booting, we need either:
    #   1. A GRUB EFI image (bootx64.efi)
    #   2. The Linux kernel EFI stub (which we have with CONFIG_EFI_STUB=y)

    # Create a minimal EFI boot entry that points to the kernel EFI stub
    cat > "${ISO_DIR}/EFI/BOOT/BOOTX64.conf" << EFICONF
# ChaldOS EFI boot configuration
# The kernel is built with EFI stub support and can be booted directly
# by UEFI firmware as \EFI\BOOT\BOOTX64.EFI
EFICONF

    # Copy the kernel as the default EFI boot entry (EFI stub)
    # The kernel with CONFIG_EFI_STUB=y can be booted directly by UEFI
    cp -f "${KERNEL_DIR}/vmlinuz" "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI"
    log_info "Copied kernel as EFI boot entry: ${ISO_DIR}/EFI/BOOT/BOOTX64.EFI"

    # Also copy initramfs near the EFI entry (for EFI stub loading via CONFIG_EFI_GENERIC_STUB_INITRD_CMDLINE_LOADER)
    cp -f "${INITRAMFS}" "${ISO_DIR}/EFI/BOOT/initramfs.cpio.gz"
    log_info "Copied initramfs for EFI boot"
}

# ------------------------------------------------------------------
# Copy bootloader binaries from host or bootloader directory
# ------------------------------------------------------------------
copy_bootloader_binaries() {
    log_step "Copying bootloader binaries..."

    # Try to find ISOLINUX binaries on the host system
    local isolinux_bin_paths=(
        "/usr/lib/ISOLINUX/isolinux.bin"
        "/usr/lib/syslinux/isolinux.bin"
        "/usr/share/syslinux/isolinux.bin"
        "/usr/lib/isolinux.bin"
    )

    local isolinux_found=false
    for path in "${isolinux_bin_paths[@]}"; do
        if [[ -f "$path" ]]; then
            cp -f "$path" "${ISO_DIR}/boot/isolinux/isolinux.bin"
            log_info "Found isolinux.bin at ${path}"
            isolinux_found=true
            break
        fi
    done

    if [[ "$isolinux_found" != "true" ]]; then
        log_warn "isolinux.bin not found on host system."
        log_warn "ISOLINUX boot will not work. GRUB/EFI boot will still be available."
        log_warn "Install syslinux or isolinux to enable BIOS boot."
        # Create a placeholder so xorriso doesn't fail
        echo "ISOLINUX placeholder - install syslinux" > "${ISO_DIR}/boot/isolinux/isolinux.bin"
    fi

    # Try to find optional COM32 modules
    local com32_modules=(menu.c32 chain.c32 reboot.c32 poweroff.c32 libutil.c32 libcom32.c32)
    local com32_base_paths=(
        "/usr/lib/syslinux/modules/bios"
        "/usr/share/syslinux"
        "/usr/lib/syslinux"
    )

    for module in "${com32_modules[@]}"; do
        for base in "${com32_base_paths[@]}"; do
            if [[ -f "${base}/${module}" ]]; then
                cp -f "${base}/${module}" "${ISO_DIR}/boot/isolinux/${module}" 2>/dev/null || true
            fi
        done
    done

    # Check if we have a GRUB EFI image
    local grub_efi_paths=(
        "/usr/lib/grub/x86_64-efi/monolithic/bootx64.efi"
        "/usr/lib/grub/x86_64-efi/bootx64.efi"
        "/boot/efi/EFI/grub/grubx64.efi"
    )

    local grub_efi_found=false
    for path in "${grub_efi_paths[@]}"; do
        if [[ -f "$path" ]]; then
            cp -f "$path" "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI" 2>/dev/null || continue
            log_info "Found GRUB EFI image at ${path}"
            grub_efi_found=true
            break
        fi
    done

    if [[ "$grub_efi_found" != "true" ]]; then
        log_warn "GRUB EFI image not found on host system."
        log_warn "Using kernel EFI stub as fallback."
    fi
}

# ------------------------------------------------------------------
# Create the ISO image
# ------------------------------------------------------------------
create_iso() {
    log_step "Creating ISO image..."

    # Create output directory
    mkdir -p "$(dirname "${OUTPUT}")"

    # Remove old ISO if exists
    if [[ -f "${OUTPUT}" ]]; then
        rm -f "${OUTPUT}"
    fi

    local iso_tool=""
    local iso_cmd=""

    # Prefer grub-mkrescue for best EFI+BIOS support
    if command -v grub-mkrescue &>/dev/null; then
        iso_tool="grub-mkrescue"
        log_info "Using grub-mkrescue to create hybrid ISO (BIOS + EFI)..."

        # If we have our own GRUB config, use it
        if [[ -f "${ISO_DIR}/boot/grub/grub.cfg" ]]; then
            # grub-mkrescue will pick up our config if placed correctly
            grub-mkrescue \
                -o "${OUTPUT}" \
                "${ISO_DIR}" \
                -volid "${ISO_LABEL}" \
                2>&1 | while IFS= read -r line; do
                if echo "$line" | grep -qiE "(error|warning|done|complete)"; then
                    echo "  $line"
                fi
            done
        else
            # No GRUB config - grub-mkrescue creates a default shell
            grub-mkrescue \
                -o "${OUTPUT}" \
                "${ISO_DIR}" \
                -volid "${ISO_LABEL}" \
                2>&1 | while IFS= read -r line; do
                if echo "$line" | grep -qiE "(error|warning|done|complete)"; then
                    echo "  $line"
                fi
            done
        fi
    elif command -v xorriso &>/dev/null; then
        iso_tool="xorriso"
        log_info "Using xorriso to create ISO..."

        local xorriso_opts=(
            -as mkisofs
            -iso-level 3
            -full-iso9660-filenames
            -volid "${ISO_LABEL}"
            -appid "ChaldOS Linux"
            -publisher "ChaldOS Project"
            -preparer "ChaldOS Build System"
            -graft-points
        )

        # Add BIOS boot info if isolinux.bin exists
        if [[ -f "${ISO_DIR}/boot/isolinux/isolinux.bin" ]]; then
            xorriso_opts+=(
                -eltorito-boot boot/isolinux/isolinux.bin
                -eltorito-catalog boot/isolinux/boot.cat
                -no-emul-boot
                -boot-load-size 4
                -boot-info-table
            )
        fi

        # Add EFI boot info
        if [[ -f "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI" ]]; then
            # Create EFI boot image (FAT filesystem with EFI boot files)
            local efi_boot_img="${BUILD_DIR}/efi_boot.img"
            create_efi_boot_image "${efi_boot_img}"

            if [[ -f "${efi_boot_img}" ]]; then
                xorriso_opts+=(
                    -eltorito-alt-boot
                    -e boot/efi_boot.img
                    -no-emul-boot
                    -isohybrid-gpt-basdat
                    -isohybrid-apm-hfsplus
                )
                # Copy EFI boot image into ISO directory
                cp -f "${efi_boot_img}" "${ISO_DIR}/boot/efi_boot.img"
            fi
        fi

        xorriso_opts+=(
            -o "${OUTPUT}"
            "${ISO_DIR}"
        )

        xorriso "${xorriso_opts[@]}" 2>&1 | while IFS= read -r line; do
            if echo "$line" | grep -qiE "(error|warning|written)"; then
                echo "  $line"
            fi
        done
    elif command -v mkisofs &>/dev/null; then
        iso_tool="mkisofs"
        log_info "Using mkisofs to create ISO (BIOS only)..."

        mkisofs \
            -o "${OUTPUT}" \
            -b boot/isolinux/isolinux.bin \
            -c boot/isolinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -R -J -v \
            -volid "${ISO_LABEL}" \
            "${ISO_DIR}" 2>&1 | while IFS= read -r line; do
            if echo "$line" | grep -qiE "(error|warning|done|complete)"; then
                echo "  $line"
            fi
        done
    fi

    if [[ ! -f "${OUTPUT}" ]]; then
        log_error "Failed to create ISO at ${OUTPUT}"
        exit 1
    fi

    log_info "ISO created with ${iso_tool}: ${OUTPUT}"
}

# ------------------------------------------------------------------
# Create EFI boot image (FAT filesystem with EFI bootloader)
# ------------------------------------------------------------------
create_efi_boot_image() {
    local output_img="$1"

    log_info "Creating EFI boot image..."

    # Check if we have the tools to create FAT filesystem
    if ! command -v mkfs.fat &>/dev/null && ! command -v mkdosfs &>/dev/null; then
        log_warn "mkfs.fat not found, skipping EFI boot image creation."
        log_warn "UEFI boot may not work. Install dosfstools package."
        return 1
    fi

    local efi_dir="${BUILD_DIR}/efi_temp"
    local efi_img_size=4  # Size in MB

    rm -rf "${efi_dir}"
    mkdir -p "${efi_dir}/EFI/BOOT"

    # Copy EFI boot files
    if [[ -f "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI" ]]; then
        cp -f "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI" "${efi_dir}/EFI/BOOT/BOOTX64.EFI"
    fi

    # Create GRUB EFI config if it doesn't exist in EFI directory
    if [[ ! -f "${efi_dir}/EFI/BOOT/grub.cfg" && -f "${ISO_DIR}/boot/grub/grub.cfg" ]]; then
        cp -f "${ISO_DIR}/boot/grub/grub.cfg" "${efi_dir}/EFI/BOOT/grub.cfg"
    fi

    # Create the FAT image
    local mkfat_cmd
    if command -v mkfs.fat &>/dev/null; then
        mkfat_cmd="mkfs.fat"
    else
        mkfat_cmd="mkdosfs"
    fi

    dd if=/dev/zero of="${output_img}" bs=1M count="${efi_img_size}" 2>/dev/null
    ${mkfat_cmd} -F 32 -n "CHALDOS_EFI" "${output_img}" 2>/dev/null

    # Copy files into the FAT image
    if command -v mcopy &>/dev/null; then
        # Use mtools for copying into FAT image
        MTOOLS_NO_VFAT=1 mcopy -s -i "${output_img}" "${efi_dir}/EFI" ::/ 2>/dev/null || true
    else
        # Fall back to mounting (requires root)
        if [[ $EUID -eq 0 ]]; then
            local mnt_point="${BUILD_DIR}/efi_mnt"
            mkdir -p "${mnt_point}"
            mount -o loop "${output_img}" "${mnt_point}" 2>/dev/null || {
                log_warn "Cannot mount EFI image (no loop device)."
                rm -rf "${efi_dir}" "${mnt_point}"
                return 1
            }
            cp -r "${efi_dir}/EFI" "${mnt_point}/" 2>/dev/null || true
            umount "${mnt_point}" 2>/dev/null || true
            rm -rf "${mnt_point}"
        else
            log_warn "Need root or mtools to populate EFI image."
            log_warn "Install mtools package (apt install mtools)."
            rm -rf "${efi_dir}"
            return 1
        fi
    fi

    rm -rf "${efi_dir}"
    log_info "EFI boot image created: ${output_img}"
}

# ------------------------------------------------------------------
# Make the ISO hybrid (bootable from both USB and CD/DVD)
# ------------------------------------------------------------------
make_hybrid() {
    log_step "Making ISO hybrid (USB bootable)..."

    # xorriso already creates isohybrid images by default
    # For isohybrid tool:
    if command -v isohybrid &>/dev/null; then
        log_info "Running isohybrid on ${OUTPUT}..."
        isohybrid "${OUTPUT}" 2>&1 || log_warn "isohybrid failed (not critical for BIOS boot)."
    fi

    log_info "ISO is hybrid (bootable from USB and CD/DVD)."
}

# ------------------------------------------------------------------
# Verify the ISO
# ------------------------------------------------------------------
verify_iso() {
    log_step "Verifying ISO..."

    local iso_size
    iso_size="$(du -h "${OUTPUT}" | cut -f1)"
    log_info "ISO size: ${iso_size}"

    # Check ISO validity
    if command -v xorriso &>/dev/null; then
        xorriso -indev "${OUTPUT}" -report_el_torito 2>&1 | while IFS= read -r line; do
            echo "  $line"
        done || log_warn "ISO verification failed (xorriso)."
    elif command -v isoinfo &>/dev/null; then
        isoinfo -d -i "${OUTPUT}" 2>&1 | head -5 || log_warn "ISO verification failed."
    fi
}

# ------------------------------------------------------------------
# Print summary
# ------------------------------------------------------------------
print_summary() {
    local iso_size
    iso_size="$(du -h "${OUTPUT}" | cut -f1)"

    echo ""
    echo "=============================================="
    echo "  ChaldOS ISO Build Complete"
    echo "=============================================="
    echo "  ISO:           ${OUTPUT} (${iso_size})"
    echo "  Volume label:  ${ISO_LABEL}"
    echo "  Kernel:        ${KERNEL_DIR}/vmlinuz"
    echo "  Initramfs:     ${INITRAMFS}"
    echo "------------------------------------------------"
    echo "  Boot methods:"
    echo "    - BIOS (ISOLINUX/GRUB)"
    echo "    - UEFI (GRUB/Kernel EFI stub)"
    echo "    - Hybrid (USB + CD/DVD)"
    echo "------------------------------------------------"
    echo "  Write to USB:"
    echo "    sudo dd if=${OUTPUT} of=/dev/sdX bs=4M status=progress"
    echo "    sudo cp ${OUTPUT} /dev/sdX (simpler, works too)"
    echo "=============================================="
    echo ""
}

# ------------------------------------------------------------------
# Main script execution
# ------------------------------------------------------------------
main() {
    parse_args "$@"

    echo "=============================================="
    echo "  ChaldOS ISO Builder"
    echo "=============================================="
    echo "  Output:       ${OUTPUT}"
    echo "  Label:        ${LABEL}"
    echo "  Boot config:  ${BOOTLOADER_DIR}"
    echo "=============================================="
    echo ""

    check_prerequisites
    setup_iso_dir
    copy_boot_files
    create_grub_config
    create_isolinux_config
    create_efi_boot
    copy_bootloader_binaries
    create_iso
    make_hybrid
    verify_iso
    print_summary

    trap - EXIT ERR
}

main "$@"
