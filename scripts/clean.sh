#!/bin/bash
#
# clean.sh
# Clean build artifacts for ChaldOS build system.
#
# Usage: ./clean.sh [option]
#   Options:
#     (none)     Clean build artifacts only (build/, initramfs_staging, iso, etc.)
#     --all      Full clean: remove build/, downloads/, and extracted sources
#     --dist     Distclean: remove everything including build artifacts
#     --help     Show this help message
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

BUILD_DIR="${PROJECT_DIR}/build"
DOWNLOAD_DIR="${PROJECT_DIR}/downloads"
SOURCES_DIR="${PROJECT_DIR}/sources"
OUTPUT_DIR="${PROJECT_DIR}/output"

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

# ------------------------------------------------------------------
# Clean build artifacts (kernel build, rootfs, initramfs, ISO dir, etc.)
# ------------------------------------------------------------------
clean_build() {
    log_step "Cleaning build artifacts..."

    local clean_count=0

    # Remove build directory (contains rootfs, initramfs staging, ISO dir, kernel build)
    if [[ -d "${BUILD_DIR}" ]]; then
        rm -rf "${BUILD_DIR}"
        log_info "Removed build directory: ${BUILD_DIR}"
        ((clean_count++))
    fi

    # Remove old output directory (legacy location)
    if [[ -d "${OUTPUT_DIR}" ]]; then
        rm -rf "${OUTPUT_DIR}"
        log_info "Removed output directory: ${OUTPUT_DIR}"
        ((clean_count++))
    fi

    # Remove any .config files generated in kernel/busybox source trees
    if [[ -d "${SOURCES_DIR}/linux" ]]; then
        if [[ -f "${SOURCES_DIR}/linux/.config" ]]; then
            rm -f "${SOURCES_DIR}/linux/.config"
            log_info "Removed kernel .config"
            ((clean_count++))
        fi
        # Clean kernel build artifacts in source tree
        if [[ -f "${SOURCES_DIR}/linux/Makefile" ]]; then
            log_info "Running 'make clean' in kernel source..."
            (cd "${SOURCES_DIR}/linux" && make clean 2>/dev/null) || true
            ((clean_count++))
        fi
    fi

    if [[ -d "${SOURCES_DIR}/busybox" ]]; then
        if [[ -f "${SOURCES_DIR}/busybox/.config" ]]; then
            rm -f "${SOURCES_DIR}/busybox/.config"
            log_info "Removed BusyBox .config"
            ((clean_count++))
        fi
        # Clean BusyBox build artifacts in source tree
        if [[ -f "${SOURCES_DIR}/busybox/Makefile" ]]; then
            log_info "Running 'make clean' in BusyBox source..."
            (cd "${SOURCES_DIR}/busybox" && make clean 2>/dev/null) || true
            ((clean_count++))
        fi
    fi

    # Remove any EFI temp directories
    rm -rf "${PROJECT_DIR}/build" 2>/dev/null || true

    if [[ $clean_count -eq 0 ]]; then
        log_info "Nothing to clean."
    else
        log_info "Cleaned ${clean_count} items."
    fi
}

# ------------------------------------------------------------------
# Full clean: remove build artifacts, downloads, and extracted sources
# ------------------------------------------------------------------
clean_all() {
    log_step "Performing full clean..."

    clean_build

    if [[ -d "${DOWNLOAD_DIR}" ]]; then
        rm -rf "${DOWNLOAD_DIR}"
        log_info "Removed downloads: ${DOWNLOAD_DIR}"
    fi

    if [[ -d "${SOURCES_DIR}" ]]; then
        rm -rf "${SOURCES_DIR}"
        log_info "Removed sources: ${SOURCES_DIR}"
    fi
}

# ------------------------------------------------------------------
# Distclean: reset everything, keeping only config files and scripts
# ------------------------------------------------------------------
clean_dist() {
    log_step "Performing distclean..."

    clean_all

    # Also clean any editor backup files and temp files
    find "${PROJECT_DIR}" -type f \
        \( -name "*~" -o -name "*.bak" -o -name "*.swp" -o -name "*.swo" \) \
        -delete 2>/dev/null || true
    log_info "Removed editor backup files."

    log_info "Distclean complete. Project is in pristine state."
}

# ------------------------------------------------------------------
# Print usage
# ------------------------------------------------------------------
print_usage() {
    echo "ChaldOS Clean Script"
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  (none)     Clean build artifacts, rootfs, initramfs, ISO"
    echo "  --all      Full clean: build artifacts + downloads + sources"
    echo "  --dist     Distclean: full clean + remove all generated files"
    echo "  --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Quick clean of build artifacts"
    echo "  $0 --all        # Full clean (redownload everything)"
    echo "  $0 --dist       # Complete reset"
}

# ------------------------------------------------------------------
# Main script execution
# ------------------------------------------------------------------
main() {
    case "${1:-}" in
        --all|-a)
            echo "=============================================="
            echo "  ChaldOS Full Clean"
            echo "=============================================="
            clean_all
            echo "=============================================="
            echo "  Full clean complete."
            echo "=============================================="
            ;;
        --dist|-d|distclean)
            echo "=============================================="
            echo "  ChaldOS Distclean"
            echo "=============================================="
            clean_dist
            echo "=============================================="
            echo "  Distclean complete."
            echo "=============================================="
            ;;
        --help|-h)
            print_usage
            ;;
        *)
            echo "=============================================="
            echo "  ChaldOS Clean Build Artifacts"
            echo "=============================================="
            clean_build
            echo "=============================================="
            echo "  Build artifacts cleaned."
            echo "=============================================="
            ;;
    esac
}

main "$@"
