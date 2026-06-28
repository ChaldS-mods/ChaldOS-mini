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

# ==================================================================
# Wayland / Weston stack downloads
# ==================================================================

LIBDRM_VERSION="2.4.120"
WAYLAND_VERSION="1.24.0"
WPROTO_VERSION="1.36"
PIXMAN_VERSION="0.42.2"
XKBCOMMON_VERSION="1.6.0"
EUDEV_VERSION="3.2.12"
LIBINPUT_VERSION="1.25.0"
WESTON_VERSION="12.0.1"

download_libdrm() {
    local filename="libdrm-${LIBDRM_VERSION}.tar.xz"
    download_file "https://dri.freedesktop.org/libdrm/${filename}" "${DOWNLOAD_DIR}/${filename}"
    extract_tarball "${DOWNLOAD_DIR}/${filename}"
}

download_wayland() {
    local filename="wayland-${WAYLAND_VERSION}.tar.xz"
    download_file "https://gitlab.freedesktop.org/wayland/wayland/-/releases/${WAYLAND_VERSION}/downloads/${filename}" "${DOWNLOAD_DIR}/${filename}"
    extract_tarball "${DOWNLOAD_DIR}/${filename}"
}

download_wayland_protocols() {
    local filename="wayland-protocols-${WPROTO_VERSION}.tar.xz"
    download_file "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/${WPROTO_VERSION}/downloads/${filename}" "${DOWNLOAD_DIR}/${filename}"
    extract_tarball "${DOWNLOAD_DIR}/${filename}"
}

download_pixman() {
    local filename="pixman-${PIXMAN_VERSION}.tar.gz"
    download_file "https://cairographics.org/releases/${filename}" "${DOWNLOAD_DIR}/${filename}"
    extract_tarball "${DOWNLOAD_DIR}/${filename}"
}

download_libxkbcommon() {
    local filename="libxkbcommon-${XKBCOMMON_VERSION}.tar.xz"
    download_file "https://xkbcommon.org/download/${filename}" "${DOWNLOAD_DIR}/${filename}"
    extract_tarball "${DOWNLOAD_DIR}/${filename}"
}

download_eudev() {
    local filename="eudev-${EUDEV_VERSION}.tar.gz"
    download_file "https://github.com/eudev-project/eudev/releases/download/v${EUDEV_VERSION}/${filename}" "${DOWNLOAD_DIR}/${filename}"
    extract_tarball "${DOWNLOAD_DIR}/${filename}"
}

download_libinput() {
    local filename="libinput-${LIBINPUT_VERSION}.tar.bz2"
    download_file "https://gitlab.freedesktop.org/libinput/libinput/-/archive/${LIBINPUT_VERSION}/${filename}" "${DOWNLOAD_DIR}/${filename}"
    extract_tarball "${DOWNLOAD_DIR}/${filename}"
}

download_weston() {
    local filename="weston-${WESTON_VERSION}.tar.xz"
    download_file "https://gitlab.freedesktop.org/wayland/weston/-/releases/${WESTON_VERSION}/downloads/${filename}" "${DOWNLOAD_DIR}/${filename}"
    extract_tarball "${DOWNLOAD_DIR}/${filename}"
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

    # West stack symlinks (used by build-wayland.sh)
    local pairs=(
        "libdrm-${LIBDRM_VERSION}" "libdrm"
        "wayland-${WAYLAND_VERSION}" "wayland"
        "wayland-protocols-${WPROTO_VERSION}" "wayland-protocols"
        "pixman-${PIXMAN_VERSION}" "pixman"
        "libxkbcommon-${XKBCOMMON_VERSION}" "libxkbcommon"
        "eudev-${EUDEV_VERSION}" "eudev"
        "libinput-${LIBINPUT_VERSION}" "libinput"
        "weston-${WESTON_VERSION}" "weston"
    )
    for ((i=0; i<${#pairs[@]}; i+=2)); do
        local ver_dir="${SOURCES_DIR}/${pairs[$i]}"
        local link="${SOURCES_DIR}/${pairs[$i+1]}"
        if [[ -d "$ver_dir" ]]; then
            ln -sfn "$ver_dir" "$link" 2>/dev/null || true
            log_info "Linked ${ver_dir} -> ${link}"
        fi
    done
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
    echo "  libdrm:  libdrm-${LIBDRM_VERSION}"
    echo "  wayland: wayland-${WAYLAND_VERSION}"
    echo "  pixman:  pixman-${PIXMAN_VERSION}"
    echo "  easton:  weston-${WESTON_VERSION}"
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
    echo "  Wayland stack:    wayland ${WAYLAND_VERSION}, weston ${WESTON_VERSION}"
    echo "=============================================="
    echo ""

    ensure_directories
    download_kernel
    download_busybox
    [[ "${SKIP_WAYLAND:-}" != "1" ]] && {
        download_libdrm
        download_wayland
        download_wayland_protocols
        download_pixman
        download_libxkbcommon
        download_eudev
        download_libinput
        download_weston
    }
    link_sources
    print_summary

    # Success — remove the trap for ERR so normal exit doesn't print warnings
    trap - EXIT ERR
}

main "$@"
