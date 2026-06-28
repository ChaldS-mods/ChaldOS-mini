#!/bin/bash
#
# download-sources.sh
# Download Linux kernel and BusyBox source tarballs from official mirrors.
#
# Usage: ./download-sources.sh [kernel_version] [busybox_version]
#   Defaults: KERNEL_VERSION=6.6.30  BUSYBOX_VERSION=1.36.1
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-${OUTPUT_DIR}/downloads}"
SOURCES_DIR="${SOURCES_DIR:-${OUTPUT_DIR}/sources}"

# Default versions
KERNEL_VERSION="${1:-6.6.30}"
BUSYBOX_VERSION="${2:-1.36.1}"

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Cleanup handler
cleanup() {
    log_warn "Script interrupted or exited with error."
}
trap cleanup EXIT ERR

# ------------------------------------------------------------------
# Create download and sources directories
# ------------------------------------------------------------------
ensure_directories() {
    mkdir -p "${DOWNLOAD_DIR}" "${SOURCES_DIR}"
    log_info "Download directory: ${DOWNLOAD_DIR}"
    log_info "Sources directory:  ${SOURCES_DIR}"
}

# ------------------------------------------------------------------
# Download a file with resume support via curl or wget
# Arguments: $1 = URL, $2 = output file path
# ------------------------------------------------------------------
download_file() {
    local url="$1"
    local output="$2"
    local filename

    filename="$(basename "$output")"

    if [[ -f "$output" ]]; then
        log_info "${filename} already exists, skipping download."
        return 0
    fi

    log_info "Downloading ${filename}..."
    log_info "  URL: ${url}"

    # Prefer curl, fallback to wget
    if command -v curl &>/dev/null; then
        curl -fSL --retry 3 --retry-delay 5 -o "${output}" "${url}" 2>&1
    elif command -v wget &>/dev/null; then
        wget --tries=3 --wait=5 -O "${output}" "${url}" 2>&1
    else
        log_error "Neither curl nor wget found. Please install one of them."
        return 1
    fi

    if [[ ! -f "$output" ]]; then
        log_error "Failed to download ${filename}"
        return 1
    fi

    log_info "Successfully downloaded ${filename}"
}

# ------------------------------------------------------------------
# Verify file integrity using SHA256 checksum if available
# Arguments: $1 = file path, $2 = expected sha256 hash
# ------------------------------------------------------------------
verify_checksum() {
    local file="$1"
    local expected_hash="$2"
    local filename

    filename="$(basename "$file")"

    if [[ -z "$expected_hash" ]]; then
        log_warn "No checksum provided for ${filename}, skipping verification."
        return 0
    fi

    if command -v sha256sum &>/dev/null; then
        local actual_hash
        actual_hash="$(sha256sum "$file" | awk '{print $1}')"
        if [[ "$actual_hash" != "$expected_hash" ]]; then
            log_error "Checksum mismatch for ${filename}"
            log_error "  Expected: ${expected_hash}"
            log_error "  Actual:   ${actual_hash}"
            return 1
        fi
        log_info "Checksum verified for ${filename}"
    else
        log_warn "sha256sum not available, skipping checksum verification."
    fi
}

# ------------------------------------------------------------------
# Extract a tar archive into the sources directory
# Arguments: $1 = archive path
# ------------------------------------------------------------------
extract_tarball() {
    local archive="$1"
    local basename
    local dest_dir

    basename="$(basename "$archive")"
    dest_dir="${SOURCES_DIR}/${basename%.tar.*}"

    if [[ -d "$dest_dir" ]]; then
        log_info "${dest_dir} already exists, skipping extraction."
        return 0
    fi

    log_info "Extracting ${basename}..."
    tar -xf "${archive}" -C "${SOURCES_DIR}"
    log_info "Extracted to ${dest_dir}"
}

# ------------------------------------------------------------------
# Download Linux kernel source
# ------------------------------------------------------------------
download_kernel() {
    local major_version
    local kernel_url
    local kernel_filename="linux-${KERNEL_VERSION}.tar.xz"
    local kernel_path="${DOWNLOAD_DIR}/${kernel_filename}"

    # Determine kernel URL based on version structure
    major_version="$(echo "$KERNEL_VERSION" | cut -d. -f1)"

    # Try multiple kernel.org mirrors
    local kernel_urls=(
        "https://cdn.kernel.org/pub/linux/kernel/v${major_version}.x/${kernel_filename}"
        "https://mirrors.kernel.org/pub/linux/kernel/v${major_version}.x/${kernel_filename}"
        "https://www.kernel.org/pub/linux/kernel/v${major_version}.x/${kernel_filename}"
    )

    local downloaded=false
    for kernel_url in "${kernel_urls[@]}"; do
        if download_file "$kernel_url" "$kernel_path"; then
            downloaded=true
            break
        fi
    done

    if [[ "$downloaded" != "true" ]]; then
        log_error "Failed to download Linux kernel from any mirror."
        return 1
    fi

    extract_tarball "$kernel_path"
}

# ------------------------------------------------------------------
# Download BusyBox source
# ------------------------------------------------------------------
download_busybox() {
    local busybox_filename="busybox-${BUSYBOX_VERSION}.tar.bz2"
    local busybox_path="${DOWNLOAD_DIR}/${busybox_filename}"

    local busybox_urls=(
        "https://busybox.net/downloads/${busybox_filename}"
        "https://mirrors.kernel.org/pub/linux/utils/busybox/${busybox_filename}"
    )

    local downloaded=false
    for busybox_url in "${busybox_urls[@]}"; do
        if download_file "$busybox_url" "$busybox_path"; then
            downloaded=true
            break
        fi
    done

    if [[ "$downloaded" != "true" ]]; then
        log_error "Failed to download BusyBox from any mirror."
        return 1
    fi

    extract_tarball "$busybox_path"
}

# ------------------------------------------------------------------
# Link downloaded sources to predictable paths
# ------------------------------------------------------------------
link_sources() {
    local kernel_src="${SOURCES_DIR}/linux-${KERNEL_VERSION}"
    local busybox_src="${SOURCES_DIR}/busybox-${BUSYBOX_VERSION}"
    local kernel_link="${SOURCES_DIR}/linux"
    local busybox_link="${SOURCES_DIR}/busybox"

    if [[ -d "$kernel_src" ]]; then
        ln -sfn "$kernel_src" "$kernel_link"
        log_info "Linked ${kernel_src} -> ${kernel_link}"
    else
        log_error "Kernel source directory ${kernel_src} not found after extraction."
        return 1
    fi

    if [[ -d "$busybox_src" ]]; then
        ln -sfn "$busybox_src" "$busybox_link"
        log_info "Linked ${busybox_src} -> ${busybox_link}"
    else
        log_error "BusyBox source directory ${busybox_src} not found after extraction."
        return 1
    fi
}

# ------------------------------------------------------------------
# Print usage information
# ------------------------------------------------------------------
print_summary() {
    echo ""
    echo "=============================================="
    echo "  ChaldOS Source Download Complete"
    echo "=============================================="
    echo "  Kernel:  linux-${KERNEL_VERSION}"
    echo "  BusyBox: busybox-${BUSYBOX_VERSION}"
    echo "------------------------------------------------"
    echo "  Downloads: ${DOWNLOAD_DIR}"
    echo "  Sources:   ${SOURCES_DIR}"
    echo "=============================================="
    echo ""
}

# ------------------------------------------------------------------
# Main script execution
# ------------------------------------------------------------------
main() {
    echo "=============================================="
    echo "  ChaldOS Source Downloader"
    echo "=============================================="
    echo "  Kernel version:   ${KERNEL_VERSION}"
    echo "  BusyBox version:  ${BUSYBOX_VERSION}"
    echo "=============================================="
    echo ""

    ensure_directories
    download_kernel
    download_busybox
    link_sources
    print_summary

    # Success — remove the trap for ERR so normal exit doesn't print warnings
    trap - EXIT ERR
}

main "$@"
