# ChaldOS Build System
# ======================
# Targets:
#   all        - Build full ChaldOS ISO
#   kernel     - Build Linux kernel
#   busybox    - Build BusyBox
#   rootfs     - Build root filesystem
#   initramfs  - Build initramfs
#   iso        - Create bootable ISO
#   install    - Install ChaldOS to device
#   clean      - Clean build artifacts
#   distclean  - Full clean (includes downloaded sources)

.PHONY: all kernel busybox rootfs initramfs iso install clean distclean

TOPDIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CONFIG := $(TOPDIR)/config
ROOTFS := $(TOPDIR)/rootfs
OUTPUT := $(TOPDIR)/output
BUILD  := $(OUTPUT)/build
IMAGES := $(OUTPUT)/images
SOURCES := $(OUTPUT)/sources
INITRAMFS := $(OUTPUT)/initramfs

# Import build config
include $(CONFIG)/chaldos.conf

# Default target
all: iso

# Create output directories
$(OUTPUT)/%:
	mkdir -p $(@)

# Download all sources
sources: | $(SOURCES)
	@echo "==> Downloading sources..."
	@$(TOPDIR)/scripts/download-sources.sh $(SOURCES)

# Build Linux kernel
kernel: sources | $(BUILD)
	@echo "==> Building Linux kernel..."
	@$(TOPDIR)/scripts/build-kernel.sh \
		--source=$(SOURCES) \
		--build=$(BUILD) \
		--config=$(CONFIG)/kernel.config \
		--output=$(IMAGES)

# Build BusyBox
busybox: sources | $(BUILD)
	@echo "==> Building BusyBox..."
	@$(TOPDIR)/scripts/build-busybox.sh \
		--source=$(SOURCES) \
		--build=$(BUILD) \
		--config=$(CONFIG)/busybox.config \
		--output=$(ROOTFS)

# Build root filesystem
rootfs: busybox
	@echo "==> Assembling root filesystem..."
	@$(TOPDIR)/scripts/build-rootfs.sh \
		--rootfs=$(ROOTFS) \
		--output=$(IMAGES)

# Build initramfs
initramfs: rootfs
	@echo "==> Building initramfs..."
	@$(TOPDIR)/scripts/build-initramfs.sh \
		--rootfs=$(ROOTFS) \
		--initramfs=$(INITRAMFS) \
		--kernel=$(IMAGES) \
		--output=$(IMAGES)

# Create bootable ISO
iso: initramfs
	@echo "==> Creating ChaldOS ISO..."
	@$(TOPDIR)/scripts/build-iso.sh \
		--kernel=$(IMAGES) \
		--initramfs=$(INITRAMFS) \
		--rootfs=$(ROOTFS) \
		--bootloader=$(TOPDIR)/bootloader \
		--config=$(CONFIG) \
		--output=$(IMAGES)

# Install to device
install:
	@echo "==> Installing ChaldOS..."
	@$(TOPDIR)/installer/install-chaldos.sh

# Clean build artifacts
clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(OUTPUT)
	@echo "    Done."

# Full clean
distclean: clean
	@echo "==> Full clean..."
	rm -rf $(SOURCES)
	@echo "    Done."

help:
	@echo "ChaldOS Build System"
	@echo "===================="
	@echo "  make all        - Build full ChaldOS ISO"
	@echo "  make kernel     - Build Linux kernel only"
	@echo "  make busybox    - Build BusyBox only"
	@echo "  make rootfs     - Assemble root filesystem"
	@echo "  make iso        - Create bootable ISO"
	@echo "  make install    - Install ChaldOS to disk"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make distclean  - Full clean (incl. sources)"
	@echo "  make help       - Show this help"
