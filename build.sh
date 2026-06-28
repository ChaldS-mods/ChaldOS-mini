#!/usr/bin/env bash
#
# ChaldOS Build Script
# =====================
# Main entry point for building ChaldOS from source.
# Detects available tools, downloads sources, compiles,
# and assembles a bootable ISO.
#
# Usage:
#   ./build.sh              - Build everything
#   ./build.sh kernel       - Build kernel only
#   ./build.sh rootfs       - Build rootfs only
#   ./build.sh iso          - Create ISO
#   ./build.sh clean        - Clean build
#   ./build.sh distclean    - Full clean
#

set -euo pipefail

CHALDOS_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$CHALDOS_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
header() { echo -e "\n${CYAN}═══ $1 ═══${NC}\n"; }

# Check build environment
check_environment() {
    header "Checking Build Environment"

    local required_tools=(
        "make:make"
        "gcc:gcc"
        "ld:binutils"
        "wget:wget"
        "tar:tar"
        "gzip:gzip"
        "bzip2:bzip2"
        "xz:xz-utils"
        "sed:sed"
        "awk:gawk"
        "patch:patch"
        "perl:perl"
        "rsync:rsync"
        "cpio:cpio"
        "dd:coreutils"
        "findutils:findutils"
        "mksquashfs:squashfs-tools"
        "xorriso:libisoburn"
        "grub-mkrescue:grub-pc"
    )

    for entry in "${required_tools[@]}"; do
        local cmd="${entry%%:*}"
        local pkg="${entry##*:}"
        if ! command -v "$cmd" &>/dev/null; then
            warn "Missing: $cmd (package: $pkg)"
        fi
    done

    # Check if running as root (not required for build)
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root — not recommended for build (use for install only)"
    fi

    # Detect architecture
    local arch
    arch=$(uname -m)
    log "Host architecture: $arch"

    # Check available memory
    if [[ -f /proc/meminfo ]]; then
        local mem_total
        mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        log "Memory: $(( mem_total / 1024 )) MB"
    fi

    log "Build environment OK"
}

# Load configuration
source_config() {
    if [[ -f config/chaldos.conf ]]; then
        source config/chaldos.conf
    fi
    # Export for sub-scripts
    export CHALDOS_ROOT CHALDOS_VERSION LINUX_VERSION BUSYBOX_VERSION
}

# Build Linux kernel
build_kernel() {
    header "Building Linux Kernel ${LINUX_VERSION}"
    ./scripts/build-kernel.sh
}

# Build BusyBox
build_busybox() {
    header "Building BusyBox ${BUSYBOX_VERSION}"
    ./scripts/build-busybox.sh
}

# Build rootfs
build_rootfs() {
    header "Building Root Filesystem"
    ./scripts/build-rootfs.sh
}

# Build initramfs
build_initramfs() {
    header "Building Initramfs"
    ./scripts/build-initramfs.sh
}

# Create ISO
build_iso() {
    header "Creating Bootable ISO"
    ./scripts/build-iso.sh
}

# Full build
build_all() {
    header "=== ChaldOS Build v${CHALDOS_VERSION} ==="
    echo "Codename: ${CHALDOS_CODENAME:-Pixel Dawn}"
    echo ""

    build_kernel
    build_busybox
    build_rootfs
    build_initramfs
    build_iso

    header "Build Complete"
    ls -lh output/images/*.iso 2>/dev/null || echo "ISO not found"
}

case "${1:-all}" in
    all)
        check_environment
        source_config
        build_all
        ;;
    kernel)
        source_config
        build_kernel
        ;;
    busybox)
        source_config
        build_busybox
        ;;
    rootfs)
        source_config
        build_rootfs
        ;;
    initramfs)
        source_config
        build_initramfs
        ;;
    iso)
        source_config
        build_iso
        ;;
    clean)
        header "Cleaning Build"
        rm -rf output/build output/images output/initramfs
        log "Cleaned build artifacts"
        ;;
    distclean)
        header "Deep Cleaning"
        rm -rf output
        log "Fully cleaned"
        ;;
    help|--help|-h)
        echo "ChaldOS Build Script — v1.0.0"
        echo ""
        echo "Usage: ./build.sh [command]"
        echo ""
        echo "Commands:"
        echo "  (no arg)    Build full ChaldOS ISO"
        echo "  kernel      Build Linux kernel only"
        echo "  busybox     Build BusyBox only"
        echo "  rootfs      Build root filesystem"
        echo "  initramfs   Build initramfs"
        echo "  iso         Create bootable ISO"
        echo "  clean       Clean build artifacts"
        echo "  distclean   Full clean (incl. sources)"
        echo "  help        Show this help"
        ;;
    *)
        error "Unknown command: $1 (use: ./build.sh help)"
        ;;
esac
