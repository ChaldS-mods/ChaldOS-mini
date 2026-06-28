#!/bin/bash
# ChaldOS Installer Library
# Shared functions for the installation process

# Check if a command exists
cmd_exists() {
    command -v "$1" &>/dev/null
}

# Check available disk space (in MB)
disk_free_mb() {
    local dir="${1:-/}"
    df -m "$dir" 2>/dev/null | tail -1 | awk '{print $4}'
}

# Get disk size in GB
disk_size_gb() {
    local dev="$1"
    if [[ -b "$dev" ]]; then
        local size=$(blockdev --getsize64 "$dev" 2>/dev/null || 0)
        echo $((size / 1073741824))
    fi
}

# Generate /etc/fstab entry
gen_fstab_entry() {
    local dev="$1" mountpoint="$2" fstype="$3" opts="${4:-defaults}"
    local uuid=$(blkid -s UUID -o value "$dev" 2>/dev/null || echo "")
    if [[ -n "$uuid" ]]; then
        echo "UUID=${uuid} ${mountpoint} ${fstype} ${opts} 0 0"
    else
        echo "${dev} ${mountpoint} ${fstype} ${opts} 0 0"
    fi
}

# Prepare installation targets
prepare_targets() {
    # EFI detection
    if [[ -d /sys/firmware/efi ]]; then
        echo "efi"
    else
        echo "bios"
    fi
}

# Check for other bootloaders
detect_bootloaders() {
    local bootloaders=()
    if command -v grub-install &>/dev/null; then
        bootloaders+=("grub")
    fi
    if command -v syslinux &>/dev/null; then
        bootloaders+=("syslinux")
    fi
    echo "${bootloaders[@]}"
}
