#!/bin/bash
#
# build-busybox.sh
# Configure and compile BusyBox with ChaldOS configuration.
# Installs to the rootfs staging directory.
#
# Usage: ./build-busybox.sh [--jobs N] [--config PATH]
#   --jobs N        Number of parallel make jobs (default: number of CPUs)
#   --config PATH   Path to BusyBox config file (default: ../config/busybox.config)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}}"
SOURCES_DIR="${SOURCES_DIR:-${OUTPUT_DIR}/sources}"
BUSYBOX_DIR="${BUSYBOX_DIR:-${SOURCES_DIR}/busybox}"
CONFIG_DIR="${PROJECT_DIR}/config"
BUILD_DIR="${BUILD_DIR:-${OUTPUT_DIR}/build}"
ROOTFS_DIR="${ROOTFS_DIR:-${BUILD_DIR}/rootfs}"

# Default number of parallel jobs = number of CPUs
NPROC="$(nproc 2>/dev/null || echo 4)"
JOBS="${NPROC}"

# Default BusyBox config path
BUSYBOX_CONFIG="${CONFIG_DIR}/busybox.config"

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()  { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()   { echo -e "${CYAN}[STEP]${NC}  $*"; }

# Cleanup handler
cleanup() {
    log_warn "Build interrupted or exited with error."
}
trap cleanup EXIT ERR

# ------------------------------------------------------------------
# Parse command-line arguments
# ------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --jobs)
                if [[ -z "${2:-}" ]]; then
                    log_error "--jobs requires an argument."
                    exit 1
                fi
                JOBS="$2"
                shift 2
                ;;
            --config)
                if [[ -z "${2:-}" ]]; then
                    log_error "--config requires an argument."
                    exit 1
                fi
                BUSYBOX_CONFIG="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [--jobs N] [--config PATH]"
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

    local required_commands=(
        make gcc ld
        gzip bzip2 xz
    )

    local missing_commands=()
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_commands[*]}"
        exit 1
    fi

    # Check for BusyBox source
    if [[ ! -d "${BUSYBOX_DIR}" ]]; then
        log_error "BusyBox source directory not found at ${BUSYBOX_DIR}"
        log_error "Run scripts/download-sources.sh first."
        exit 1
    fi

    # Check for config file
    if [[ ! -f "${BUSYBOX_CONFIG}" ]]; then
        log_error "BusyBox config not found at ${BUSYBOX_CONFIG}"
        exit 1
    fi

    log_info "All prerequisites met."
}

# ------------------------------------------------------------------
# Prepare BusyBox source tree
# ------------------------------------------------------------------
prepare_source() {
    log_step "Preparing BusyBox source tree..."

    cd "${BUSYBOX_DIR}"

    # Clean any previous build artifacts
    if [[ -f "Makefile" ]]; then
        make distclean 2>/dev/null || true
    fi

    log_info "BusyBox source tree ready at ${BUSYBOX_DIR}"
}

# ------------------------------------------------------------------
# Configure BusyBox
# ------------------------------------------------------------------
configure_busybox() {
    log_step "Configuring BusyBox..."

    cd "${BUSYBOX_DIR}"

    # Copy our config as .config
    cp -f "${BUSYBOX_CONFIG}" ".config"
    log_info "Copied config from ${BUSYBOX_CONFIG}"

    # Update config against the BusyBox source tree
    yes "" | make oldconfig 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qiE "(error|warning)"; then
            log_info "  oldconfig: ${line}"
        fi
    done

    # Save the final config for reference
    mkdir -p "${BUILD_DIR}"
    cp -f ".config" "${BUILD_DIR}/busybox-built.config"
    log_info "Saved final config to ${BUILD_DIR}/busybox-built.config"

    log_info "BusyBox configuration complete."
}

# ------------------------------------------------------------------
# Build BusyBox
# ------------------------------------------------------------------
build_busybox() {
    log_step "Building BusyBox (${JOBS} parallel jobs)..."

    cd "${BUSYBOX_DIR}"

    # Build BusyBox
    make -j"${JOBS}" 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qiE "(error|warning|fatal|cannot|failed)"; then
            echo "  $line"
        fi
    done

    log_info "BusyBox build complete."

    # Verify the binary was created
    if [[ ! -f "busybox" ]]; then
        log_error "BusyBox binary not found after build!"
        exit 1
    fi

    local busybox_size
    busybox_size="$(du -h "busybox" | cut -f1)"
    log_info "BusyBox binary size: ${busybox_size}"

    # Check if it's a static binary
    if ldd "busybox" 2>&1 | grep -qi "not a dynamic executable"; then
        log_info "BusyBox is statically linked."
    else
        log_warn "BusyBox is dynamically linked. Ensure libraries are available in rootfs."
        ldd "busybox" 2>&1 | while IFS= read -r line; do
            log_warn "  Dependency: ${line}"
        done
    fi
}

# ------------------------------------------------------------------
# Install BusyBox to rootfs
# ------------------------------------------------------------------
install_busybox() {
    log_step "Installing BusyBox to rootfs..."

    cd "${BUSYBOX_DIR}"

    # Ensure rootfs target directory exists
    mkdir -p "${ROOTFS_DIR}"

    # Install BusyBox and create symlinks
    make CONFIG_PREFIX="${ROOTFS_DIR}" install 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qiE "(error|warning|installed|link)"; then
            echo "  $line"
        fi
    done

    # Verify installation
    if [[ ! -f "${ROOTFS_DIR}/bin/busybox" ]]; then
        log_error "BusyBox not installed to ${ROOTFS_DIR}/bin/busybox"
        exit 1
    fi

    log_info "BusyBox installed to ${ROOTFS_DIR}"
}

# ------------------------------------------------------------------
# Print build summary
# ------------------------------------------------------------------
print_summary() {
    local busybox_size="N/A"
    if [[ -f "${ROOTFS_DIR}/bin/busybox" ]]; then
        busybox_size="$(du -h "${ROOTFS_DIR}/bin/busybox" | cut -f1)"
    fi

    local applet_count=0
    if [[ -d "${ROOTFS_DIR}/bin" ]]; then
        applet_count="$(find "${ROOTFS_DIR}/bin" -type l -o -type f | wc -l)"
    fi

    echo ""
    echo "=============================================="
    echo "  ChaldOS BusyBox Build Complete"
    echo "=============================================="
    echo "  Binary:       ${ROOTFS_DIR}/bin/busybox (${busybox_size})"
    echo "  Applets:      ${applet_count}"
    echo "  Build config: ${BUILD_DIR}/busybox-built.config"
    echo "  Parallel jobs: ${JOBS}"
    echo "=============================================="
    echo ""
}

# ------------------------------------------------------------------
# Main script execution
# ------------------------------------------------------------------
main() {
    parse_args "$@"

    echo "=============================================="
    echo "  ChaldOS BusyBox Builder"
    echo "=============================================="
    echo "  BusyBox source: ${BUSYBOX_DIR}"
    echo "  Config file:    ${BUSYBOX_CONFIG}"
    echo "  Install dir:    ${ROOTFS_DIR}"
    echo "  Build jobs:     ${JOBS}"
    echo "=============================================="
    echo ""

    check_prerequisites
    prepare_source
    configure_busybox
    build_busybox
    install_busybox
    print_summary

    # Remove error trap on success
    trap - EXIT ERR
}

main "$@"
