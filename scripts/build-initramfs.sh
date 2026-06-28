#!/bin/bash
#
# build-initramfs.sh
# Build the initramfs for ChaldOS:
#   - Create compressed cpio archive of the root filesystem
#   - Optionally include kernel modules
#   - Produce initramfs image suitable for booting
#
# Usage: ./build-initramfs.sh [--compress gz|lz4|xz] [--output PATH]
#   --compress ALGO    Compression algorithm (gz, lz4, xz, zstd) (default: gz)
#   --output PATH      Output file path (default: ../build/initramfs.cpio.gz)
#   --no-modules       Exclude kernel modules from initramfs
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}}"
BUILD_DIR="${BUILD_DIR:-${OUTPUT_DIR}/build}"
ROOTFS_DIR="${ROOTFS_DIR:-${BUILD_DIR}/rootfs}"
INITRAMFS_DIR="${INITRAMFS_DIR:-${BUILD_DIR}/initramfs_staging}"
IMAGES_DIR="${IMAGES_DIR:-${OUTPUT_DIR}/images}"
OUTPUT="${OUTPUT:-${IMAGES_DIR}/initramfs.cpio.gz}"
COMPRESSION_ALGO="gzip"
INCLUDE_MODULES=true

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
    log_warn "Initramfs build interrupted or exited with error."
}
trap cleanup EXIT ERR

# ------------------------------------------------------------------
# Parse command-line arguments
# ------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --compress)
                if [[ -z "${2:-}" ]]; then
                    log_error "--compress requires an argument (gz, lz4, xz, zstd)."
                    exit 1
                fi
                COMPRESSION_ALGO="$2"
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
            --no-modules)
                INCLUDE_MODULES=false
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--compress gz|lz4|xz|zstd] [--output PATH] [--no-modules]"
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

    if [[ ! -d "${ROOTFS_DIR}" ]]; then
        log_error "RootFS directory not found at ${ROOTFS_DIR}"
        log_error "Run build-rootfs.sh first."
        exit 1
    fi

    # Check that cpio is available
    if ! command -v cpio &>/dev/null; then
        log_error "cpio not found. Please install it."
        exit 1
    fi

    # Check that the rootfs has init or linuxrc
    if [[ ! -f "${ROOTFS_DIR}/init" && ! -f "${ROOTFS_DIR}/linuxrc" ]]; then
        log_warn "No /init or /linuxrc found in rootfs."
        log_warn "BusyBox init will be used as /init (symlink handled by make install)."
    fi

    # Verify compression tools
    case "${COMPRESSION_ALGO}" in
        gz|gzip)
            if ! command -v gzip &>/dev/null; then
                log_error "gzip not found."
                exit 1
            fi
            OUTPUT="${OUTPUT%.*}.cpio.gz" 2>/dev/null || OUTPUT="${BUILD_DIR}/initramfs.cpio.gz"
            ;;
        lz4)
            if ! command -v lz4 &>/dev/null; then
                log_error "lz4 not found."
                exit 1
            fi
            OUTPUT="${OUTPUT%.*}.cpio.lz4"
            ;;
        xz)
            if ! command -v xz &>/dev/null; then
                log_error "xz not found."
                exit 1
            fi
            OUTPUT="${OUTPUT%.*}.cpio.xz"
            ;;
        zstd)
            if ! command -v zstd &>/dev/null; then
                log_error "zstd not found."
                exit 1
            fi
            OUTPUT="${OUTPUT%.*}.cpio.zst"
            ;;
        *)
            log_error "Unknown compression algorithm: ${COMPRESSION_ALGO}"
            log_error "Supported: gz, lz4, xz, zstd"
            exit 1
            ;;
    esac

    log_info "All prerequisites met."
}

# ------------------------------------------------------------------
# Strip binaries to reduce initramfs size
# ------------------------------------------------------------------
strip_binaries() {
    log_step "Stripping binaries to reduce size..."

    if command -v strip &>/dev/null; then
        # Strip ELF binaries and libraries
        find "${ROOTFS_DIR}" -type f \
            \( -name "busybox" -o -name "*.so*" -o -name "*.ko" \) \
            -exec strip --strip-unneeded {} \; 2>/dev/null || true
        log_info "Binaries stripped."
    else
        log_warn "strip not found, skipping binary stripping."
    fi
}

# ------------------------------------------------------------------
# Create staging directory for initramfs
# ------------------------------------------------------------------
create_staging() {
    log_step "Creating initramfs staging directory..."

    # Remove any previous staging
    if [[ -d "${INITRAMFS_DIR}" ]]; then
        rm -rf "${INITRAMFS_DIR}"
    fi

    # Copy rootfs to staging
    cp -a "${ROOTFS_DIR}" "${INITRAMFS_DIR}"
    log_info "RootFS copied to staging: ${INITRAMFS_DIR}"
}

# ------------------------------------------------------------------
# Optionally strip modules to only what's needed
# ------------------------------------------------------------------
strip_modules() {
    if [[ "$INCLUDE_MODULES" != "true" ]]; then
        log_step "Excluding kernel modules from initramfs..."
        if [[ -d "${INITRAMFS_DIR}/lib/modules" ]]; then
            rm -rf "${INITRAMFS_DIR}/lib/modules"
            log_info "Kernel modules removed from initramfs."
        fi
    else
        log_step "Including kernel modules in initramfs..."

        if [[ -d "${INITRAMFS_DIR}/lib/modules" ]]; then
            local modules_size
            modules_size="$(du -sh "${INITRAMFS_DIR}/lib/modules" 2>/dev/null | cut -f1)"
            log_info "Modules size: ${modules_size}"

            # Show available module categories
            log_info "Available module categories:"
            find "${INITRAMFS_DIR}/lib/modules" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r moddir; do
                local modname
                modname="$(basename "$moddir")"
                local modcount
                modcount="$(find "${moddir}" -name '*.ko' 2>/dev/null | wc -l)"
                log_info "  ${modname}: ${modcount} modules"
            done
        else
            log_warn "No kernel modules found at ${INITRAMFS_DIR}/lib/modules"
        fi
    fi
}

# ------------------------------------------------------------------
# Create /init script (wrapper if not already present)
# ------------------------------------------------------------------
create_init_script() {
    log_step "Ensuring /init script exists..."

    if [[ ! -f "${INITRAMFS_DIR}/init" ]]; then
        # Create a minimal /init that hands off to BusyBox init
        cat > "${INITRAMFS_DIR}/init" << 'INITSCRIPT'
#!/bin/sh
#
# /init - ChaldOS initramfs init script
#

# Mount essential filesystems
/bin/mount -t proc proc /proc
/bin/mount -t sysfs sysfs /sys
/bin/mount -t devtmpfs devtmpfs /dev

# Create essential device nodes if devtmpfs didn't
/bin/mknod /dev/console c 5 1 2>/dev/null || true
/bin/mknod /dev/null c 1 3 2>/dev/null || true
/bin/mknod /dev/tty c 5 0 2>/dev/null || true

# Set up basic environment
export PATH="/sbin:/bin:/usr/sbin:/usr/bin"

# Start the real init
exec /sbin/init
INITSCRIPT
        chmod 0755 "${INITRAMFS_DIR}/init"
        log_info "Created /init script."
    else
        log_info "/init already exists."
    fi
}

# ------------------------------------------------------------------
# Build the cpio archive
# ------------------------------------------------------------------
build_cpio() {
    log_step "Creating cpio archive..."

    # Create output directory
    mkdir -p "$(dirname "${OUTPUT}")"

    # Remove old initramfs if exists
    if [[ -f "${OUTPUT}" ]]; then
        rm -f "${OUTPUT}"
    fi

    local cpio_size

    # Create cpio archive and compress it
    case "${COMPRESSION_ALGO}" in
        gz|gzip)
            log_info "Compressing with gzip..."
            (cd "${INITRAMFS_DIR}" && find . -print0 | cpio --null -o -H newc --quiet | gzip -9) > "${OUTPUT}"
            ;;
        lz4)
            log_info "Compressing with lz4..."
            (cd "${INITRAMFS_DIR}" && find . -print0 | cpio --null -o -H newc --quiet | lz4 -9) > "${OUTPUT}"
            ;;
        xz)
            log_info "Compressing with xz..."
            # XZ with extreme compression, but using multiple threads if available
            local xz_opts="-9 --check=crc32"
            if command -v nproc &>/dev/null; then
                local ncpus
                ncpus="$(nproc)"
                xz_opts="${xz_opts} -T${ncpus}"
            fi
            (cd "${INITRAMFS_DIR}" && find . -print0 | cpio --null -o -H newc --quiet | xz ${xz_opts}) > "${OUTPUT}"
            ;;
        zstd)
            log_info "Compressing with zstd..."
            local zstd_opts="-19 -T0"
            (cd "${INITRAMFS_DIR}" && find . -print0 | cpio --null -o -H newc --quiet | zstd ${zstd_opts}) > "${OUTPUT}"
            ;;
    esac

    if [[ ! -f "${OUTPUT}" ]]; then
        log_error "Failed to create initramfs at ${OUTPUT}"
        exit 1
    fi

    cpio_size="$(du -h "${OUTPUT}" | cut -f1)"
    log_info "Initramfs created: ${OUTPUT} (${cpio_size})"
}

# ------------------------------------------------------------------
# Verify the initramfs archive
# ------------------------------------------------------------------
verify_initramfs() {
    log_step "Verifying initramfs..."

    local file_type
    file_type="$(file "${OUTPUT}" 2>/dev/null || echo "unknown")"
    log_info "File type: ${file_type}"

    # Test that the cpio is valid by listing contents
    local temp_dir
    temp_dir="$(mktemp -d)"
    if (cd "${temp_dir}" && zcat "${OUTPUT}" 2>/dev/null | cpio -t --quiet 2>/dev/null) >/dev/null 2>&1; then
        local file_count
        file_count="$(cd "${temp_dir}" && zcat "${OUTPUT}" 2>/dev/null | cpio -t --quiet 2>/dev/null | wc -l)"
        log_info "Archive valid: ${file_count} files."
    else
        log_warn "Could not verify cpio archive contents."
    fi
    rm -rf "${temp_dir}"
}

# ------------------------------------------------------------------
# Print summary
# ------------------------------------------------------------------
print_summary() {
    local initramfs_size
    initramfs_size="$(du -h "${OUTPUT}" 2>/dev/null | cut -f1)"

    local rootfs_size
    rootfs_size="$(du -sh "${INITRAMFS_DIR}" 2>/dev/null | cut -f1)"

    echo ""
    echo "=============================================="
    echo "  ChaldOS Initramfs Build Complete"
    echo "=============================================="
    echo "  Output:         ${OUTPUT} (${initramfs_size})"
    echo "  Staging size:   ${rootfs_size}"
    echo "  Compression:    ${COMPRESSION_ALGO}"
    echo "  Includes mods:  ${INCLUDE_MODULES}"
    echo "=============================================="
    echo ""
}

# ------------------------------------------------------------------
# Main script execution
# ------------------------------------------------------------------
main() {
    parse_args "$@"

    echo "=============================================="
    echo "  ChaldOS Initramfs Builder"
    echo "=============================================="
    echo "  RootFS:       ${ROOTFS_DIR}"
    echo "  Output:       ${OUTPUT}"
    echo "  Compression:  ${COMPRESSION_ALGO}"
    echo "  Modules:      ${INCLUDE_MODULES}"
    echo "=============================================="
    echo ""

    check_prerequisites
    strip_binaries
    create_staging
    strip_modules
    create_init_script
    build_cpio
    verify_initramfs
    print_summary

    trap - EXIT ERR
}

main "$@"
