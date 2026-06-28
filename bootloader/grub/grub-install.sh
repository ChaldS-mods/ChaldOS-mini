# ChaldOS — GRUB Installation Script
# /bootloader/grub/grub-install.sh

#!/bin/sh

set -euo pipefail

CHALDOS_ROOT="${CHALDOS_ROOT:-/}"
INSTALL_DEV="${INSTALL_DEV:-/dev/sda}"

if [[ ! -b "$INSTALL_DEV" ]]; then
    echo "Error: $INSTALL_DEV is not a block device"
    exit 1
fi

echo "Installing GRUB to $INSTALL_DEV..."

# Install GRUB for BIOS/legacy boot
if [[ -d /sys/firmware/efi ]]; then
    echo "EFI system detected"
    grub-install --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --boot-directory=/boot \
        --recheck \
        --no-floppy
else
    echo "BIOS/Legacy system detected"
    grub-install --target=i386-pc \
        --boot-directory=/boot \
        --recheck \
        --no-floppy \
        "$INSTALL_DEV"
fi

# Copy our config
cp -f /bootloader/grub/grub.cfg /boot/grub/grub.cfg

echo "GRUB installation complete."
