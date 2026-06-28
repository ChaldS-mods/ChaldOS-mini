#!/bin/bash
#
# build-kernel.sh
# Configure and compile the Linux kernel with ChaldOS configuration.
# Installs modules to the rootfs staging directory.
#
# Usage: ./build-kernel.sh [--jobs N] [--config PATH]
#   --jobs N        Number of parallel make jobs (default: number of CPUs)
#   --config PATH   Path to kernel config file (default: ../config/kernel.config)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}}"
SOURCES_DIR="${SOURCES_DIR:-${OUTPUT_DIR}/sources}"
KERNEL_DIR="${KERNEL_DIR:-${SOURCES_DIR}/linux}"
CONFIG_DIR="${PROJECT_DIR}/config"
BUILD_DIR="${BUILD_DIR:-${OUTPUT_DIR}/build}"
ROOTFS_DIR="${ROOTFS_DIR:-${BUILD_DIR}/rootfs}"
KERNEL_BUILD_DIR="${KERNEL_BUILD_DIR:-${BUILD_DIR}/kernel}"

# Default number of parallel jobs = number of CPUs
NPROC="$(nproc 2>/dev/null || echo 4)"
JOBS="${NPROC}"

# Default kernel config path
KERNEL_CONFIG="${CONFIG_DIR}/kernel.config"

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
                KERNEL_CONFIG="$2"
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
        make gcc ld as
        bc bison flex
        gzip xz
        pkg-config
        openssl
    )

    local missing_commands=()
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_commands[*]}"
        log_error "Install them with your distribution's package manager."
        log_error "  Debian/Ubuntu: apt install build-essential bc bison flex libssl-dev libelf-dev"
        log_error "  Fedora/RHEL:   dnf install gcc make bc bison flex openssl-devel elfutils-libelf-devel"
        exit 1
    fi

    # Check for kernel source
    if [[ ! -d "${KERNEL_DIR}" ]]; then
        log_error "Kernel source directory not found at ${KERNEL_DIR}"
        log_error "Run scripts/download-sources.sh first."
        exit 1
    fi

    # Check for kernel config
    if [[ ! -f "${KERNEL_CONFIG}" ]]; then
        log_error "Kernel config not found at ${KERNEL_CONFIG}"
        exit 1
    fi

    log_info "All prerequisites met."
}

# ------------------------------------------------------------------
# Prepare kernel source tree
# ------------------------------------------------------------------
prepare_source() {
    log_step "Preparing kernel source tree..."

    cd "${KERNEL_DIR}"

    # Clean any previous build artifacts in the source tree
    if [[ -f "Makefile" ]]; then
        make mrproper 2>/dev/null || true
    fi

    log_info "Kernel source tree ready at ${KERNEL_DIR}"
}

# ------------------------------------------------------------------
# Configure the kernel
# ------------------------------------------------------------------
configure_kernel() {
    log_step "Configuring kernel..."

    cd "${KERNEL_DIR}"

    # Copy our config as .config
    cp -f "${KERNEL_CONFIG}" ".config"
    log_info "Copied config from ${KERNEL_CONFIG}"

    # Update config against the kernel source (handles new/changed options)
    make olddefconfig 2>&1 | while IFS= read -r line; do
        log_info "  olddefconfig: ${line}"
    done

    # Verify that the resulting config has our critical options
    verify_config_option "CONFIG_64BIT" "y"
    verify_config_option "CONFIG_SMP" "y"
    verify_config_option "CONFIG_EXT4_FS" "y"
    verify_config_option "CONFIG_SQUASHFS" "y"
    verify_config_option "CONFIG_DRM" "y"
    verify_config_option "CONFIG_USB" "y"
    verify_config_option "CONFIG_EFI" "y"
    verify_config_option "CONFIG_NET" "y"

    # Save the final config for reference
    mkdir -p "${BUILD_DIR}"
    cp -f ".config" "${BUILD_DIR}/kernel-built.config"
    log_info "Saved final config to ${BUILD_DIR}/kernel-built.config"

    log_info "Kernel configuration complete."
}

# ------------------------------------------------------------------
# Verify that a given CONFIG option is set to expected value
# ------------------------------------------------------------------
verify_config_option() {
    local option="$1"
    local expected="$2"
    local actual

    if grep -q "^${option}=${expected}" ".config"; then
        log_info "  Verified ${option}=${expected}"
    else
        actual="$(grep "^${option}=" ".config" 2>/dev/null || echo "not set")"
        log_warn "  ${option} is ${actual} (expected ${expected})"
    fi
}

# ------------------------------------------------------------------
# Build the kernel and modules
# ------------------------------------------------------------------
build_kernel() {
    log_step "Building kernel (${JOBS} parallel jobs)..."
    log_info "This may take a while. Go grab a coffee."

    cd "${KERNEL_DIR}"

    # Build the kernel binary
    make -j"${JOBS}" bzImage 2>&1 | while IFS= read -r line; do
        # Only show lines that are warnings or errors to keep output manageable
        if echo "$line" | grep -qiE "(error|warning|fatal|cannot|failed)"; then
            echo "  $line"
        fi
    done

    # Build kernel modules
    make -j"${JOBS}" modules 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qiE "(error|warning|fatal|cannot|failed)"; then
            echo "  $line"
        fi
    done

    log_info "Kernel build complete."
}

# ------------------------------------------------------------------
# Install kernel and modules
# ------------------------------------------------------------------
install_kernel() {
    log_step "Installing kernel and modules..."

    cd "${KERNEL_DIR}"

    # Create installation directories
    mkdir -p "${KERNEL_BUILD_DIR}"
    mkdir -p "${ROOTFS_DIR}/lib/modules"

    # Install kernel binary
    cp -f "arch/x86_64/boot/bzImage" "${KERNEL_BUILD_DIR}/vmlinuz"
    log_info "Installed kernel: ${KERNEL_BUILD_DIR}/vmlinuz"

    # Install kernel System.map
    cp -f "System.map" "${KERNEL_BUILD_DIR}/System.map"
    log_info "Installed System.map"

    # Install kernel config
    cp -f ".config" "${KERNEL_BUILD_DIR}/config"
    log_info "Installed kernel config"

    # Install modules to rootfs
    make INSTALL_MOD_PATH="${ROOTFS_DIR}" modules_install 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qiE "(error|warning|fatal|cannot|failed|installed)"; then
            echo "  $line"
        fi
    done

    log_info "Modules installed to ${ROOTFS_DIR}/lib/modules"

    # Generate module dependencies
    if command -v depmod &>/dev/null; then
        local kernel_release
        kernel_release="$(cat "${KERNEL_DIR}/include/config/kernel.release" 2>/dev/null || true)"
        if [[ -n "$kernel_release" ]]; then
            depmod -b "${ROOTFS_DIR}" "$kernel_release" 2>/dev/null || true
            log_info "Generated module dependencies"
        fi
    fi
}

# ------------------------------------------------------------------
# Print build summary
# ------------------------------------------------------------------
print_summary() {
    local kernel_size

    if [[ -f "${KERNEL_BUILD_DIR}/vmlinuz" ]]; then
        kernel_size="$(du -h "${KERNEL_BUILD_DIR}/vmlinuz" | cut -f1)"
    else
        kernel_size="N/A"
    fi

    local modules_size
    if [[ -d "${ROOTFS_DIR}/lib/modules" ]]; then
        modules_size="$(du -sh "${ROOTFS_DIR}/lib/modules" 2>/dev/null | cut -f1)"
    else
        modules_size="N/A"
    fi

    echo ""
    echo "=============================================="
    echo "  ChaldOS Kernel Build Complete"
    echo "=============================================="
    echo "  Kernel binary:  ${KERNEL_BUILD_DIR}/vmlinuz (${kernel_size})"
    echo "  Build config:   ${BUILD_DIR}/kernel-built.config"
    echo "  Modules:        ${ROOTFS_DIR}/lib/modules (${modules_size})"
    echo "  Parallel jobs:  ${JOBS}"
    echo "=============================================="
    echo ""
}

# ------------------------------------------------------------------
# Main script execution
# ------------------------------------------------------------------
main() {
    parse_args "$@"

    echo "=============================================="
    echo "  ChaldOS Kernel Builder"
    echo "=============================================="
    echo "  Kernel source:  ${KERNEL_DIR}"
    echo "  Kernel config:  ${KERNEL_CONFIG}"
    echo "  Build jobs:     ${JOBS}"
    echo "=============================================="
    echo ""

    check_prerequisites
    prepare_source
    configure_kernel
    build_kernel
    install_kernel
    print_summary

    # Remove error trap on success
    trap - EXIT ERR
}

main "$@"
