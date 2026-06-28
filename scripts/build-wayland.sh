#!/bin/bash
#
# build-wayland.sh
# Build the Wayland stack for ChaldOS:
#   libdrm → wayland → wayland-protocols → pixman → libxkbcommon
#   → eudev → libinput → weston
#
# All built from source into a staging directory, then merged into rootfs.
#
# Usage: ./build-wayland.sh [--jobs N] [--output PATH]
#   --jobs N        Number of parallel make jobs (default: number of CPUs)
#   --output PATH   Output rootfs path (default: ../build/rootfs)
#
# Environment variables:
#   OUTPUT_DIR    — base output directory (default: PROJECT_DIR)
#   STAGING_DIR   — temporary staging for built libraries (default: BUILD_DIR/staging)
#   ROOTFS_DIR    — target rootfs (default: BUILD_DIR/rootfs)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}}"
SOURCES_DIR="${SOURCES_DIR:-${OUTPUT_DIR}/sources}"
BUILD_DIR="${BUILD_DIR:-${OUTPUT_DIR}/build}"
STAGING_DIR="${STAGING_DIR:-${BUILD_DIR}/wayland-staging}"
ROOTFS_DIR="${ROOTFS_DIR:-${BUILD_DIR}/rootfs}"

NPROC="$(nproc 2>/dev/null || echo 4)"
JOBS="${NPROC}"

# Version definitions
LIBDRM_VERSION="2.4.120"
WAYLAND_VERSION="1.22.0"
WPROTO_VERSION="1.36"
PIXMAN_VERSION="0.42.2"
XKBCOMMON_VERSION="1.6.0"
EUDEV_VERSION="3.2.12"
LIBINPUT_VERSION="1.25.0"
WESTON_VERSION="12.0.1"

# Color helpers
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
log_info()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()  { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()   { echo -e "${CYAN}[STEP]${NC}  $*"; }

cleanup() { log_warn "Wayland build interrupted."; }
trap cleanup EXIT ERR

# ------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --jobs)
                JOBS="${2?--jobs requires an argument}"
                shift 2 ;;
            --output)
                ROOTFS_DIR="${2?--output requires an argument}"
                shift 2 ;;
            --help|-h)
                echo "Usage: $0 [--jobs N] [--output PATH]"; exit 0 ;;
            *) log_error "Unknown: $1"; exit 1 ;;
        esac
    done
}

# ------------------------------------------------------------------
# Prerequisites
# ------------------------------------------------------------------
check_prereqs() {
    log_step "Checking prerequisites..."
    local required=(make gcc pkg-config meson ninja)
    local missing=()
    for cmd in "${required[@]}"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing: ${missing[*]}"
        log_error "Install: apt install meson ninja-build pkg-config build-essential"
        exit 1
    fi
    # Check source directories exist
    local pkgs=(
        "libdrm-${LIBDRM_VERSION}" "${SOURCES_DIR}/libdrm-${LIBDRM_VERSION}"
        "wayland-${WAYLAND_VERSION}" "${SOURCES_DIR}/wayland-${WAYLAND_VERSION}"
        "wayland-protocols-${WPROTO_VERSION}" "${SOURCES_DIR}/wayland-protocols-${WPROTO_VERSION}"
        "pixman-${PIXMAN_VERSION}" "${SOURCES_DIR}/pixman-${PIXMAN_VERSION}"
        "libxkbcommon-${XKBCOMMON_VERSION}" "${SOURCES_DIR}/libxkbcommon-${XKBCOMMON_VERSION}"
        "eudev-${EUDEV_VERSION}" "${SOURCES_DIR}/eudev-${EUDEV_VERSION}"
        "libinput-${LIBINPUT_VERSION}" "${SOURCES_DIR}/libinput-${LIBINPUT_VERSION}"
        "weston-${WESTON_VERSION}" "${SOURCES_DIR}/weston-${WESTON_VERSION}"
    )
    local all_ok=true
    for ((i=0; i<${#pkgs[@]}; i+=2)); do
        local name="${pkgs[$i]}" dir="${pkgs[$i+1]}"
        if [[ ! -d "$dir" ]]; then
            log_error "Missing source: $name (expected at $dir)"
            log_error "Run scripts/download-sources.sh first."
            all_ok=false
        fi
    done
    $all_ok || exit 1
    log_info "All prerequisites met."
}

# ------------------------------------------------------------------
# Prepare staging dirs
# ------------------------------------------------------------------
prepare_dirs() {
    log_step "Preparing directories..."
    rm -rf "$STAGING_DIR"
    mkdir -p "$STAGING_DIR/usr/lib"
    mkdir -p "$STAGING_DIR/usr/include"
    mkdir -p "$ROOTFS_DIR"
    export PKG_CONFIG_PATH="$STAGING_DIR/usr/lib/pkgconfig:$STAGING_DIR/usr/share/pkgconfig"
    export LD_LIBRARY_PATH="$STAGING_DIR/usr/lib:$LD_LIBRARY_PATH"
    export PATH="$STAGING_DIR/usr/bin:$PATH"
    export CPATH="$STAGING_DIR/usr/include:$CPATH"
    log_info "Staging: $STAGING_DIR"
    log_info "RootFS:  $ROOTFS_DIR"
}

# ------------------------------------------------------------------
# meson build helper: configure, compile, install to staging
# ------------------------------------------------------------------
meson_build() {
    local pkg_name="$1"    # human-readable name
    local src_dir="$2"     # path to source
    local extra_args="$3"  # extra meson args (optional)
    local dir_suffix="${4:-build}"  # build dir suffix

    log_step "Building $pkg_name..."
    cd "$src_dir"

    local build_dir="${src_dir}/build-${dir_suffix}"
    rm -rf "$build_dir"

    meson setup "$build_dir" \
        --prefix=/usr \
        --libdir=lib \
        --buildtype=release \
        -Db_ndebug=true \
        -Ddocumentation=false \
        -Dtests=false \
        -Dtest-helpers=false \
        -Dnls=false \
        ${extra_args:-} 2>&1 | while IFS= read -r line; do
            echo "  meson: $line"
        done

    ninja -j"${JOBS}" -C "$build_dir" 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qiE "(error|warning|FAILED)"; then
            echo "  $line"
        fi
    done

    DESTDIR="$STAGING_DIR" ninja -C "$build_dir" install 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qiE "(error|warning|installed)"; then
            echo "  $line"
        fi
    done

    cd "$SCRIPT_DIR"
    log_info "$pkg_name built and installed to staging."
}

# ------------------------------------------------------------------
# Build libdrm (userspace DRM interface)
# ------------------------------------------------------------------
build_libdrm() {
    meson_build "libdrm" \
        "${SOURCES_DIR}/libdrm-${LIBDRM_VERSION}" \
        "-Dudev=true -Dintel=true -Damdgpu=true -Dradeon=true -Dnouveau=true -Dvc4=false -Dvmwgfx=false -Dexynos=false -Dfreedreno=false -Detnaviv=false -Dtegra=false"
}

# ------------------------------------------------------------------
# Build wayland core libraries
# ------------------------------------------------------------------
build_wayland() {
    meson_build "wayland" \
        "${SOURCES_DIR}/wayland-${WAYLAND_VERSION}" \
        "-Ddocumentation=false -Ddtd_validation=false"
}

# ------------------------------------------------------------------
# Build wayland-protocols (just XML data files)
# ------------------------------------------------------------------
build_wayland_protocols() {
    meson_build "wayland-protocols" \
        "${SOURCES_DIR}/wayland-protocols-${WPROTO_VERSION}" ""
}

# ------------------------------------------------------------------
# Build pixman (software pixel rendering)
# ------------------------------------------------------------------
build_pixman() {
    meson_build "pixman" \
        "${SOURCES_DIR}/pixman-${PIXMAN_VERSION}" \
        "-Darm-simd=false -Da64-neon=false -Dgnu-inline-asm=false -Dloongson-mmi=false -Dvmx=false -Dmmx=false -Dsse2=false -Dssse3=false"
}

# ------------------------------------------------------------------
# Build libxkbcommon (keyboard layout)
# ------------------------------------------------------------------
build_libxkbcommon() {
    meson_build "libxkbcommon" \
        "${SOURCES_DIR}/libxkbcommon-${XKBCOMMON_VERSION}" \
        "-Denable-xkbregistry=false -Denable-docs=false"
}

# ------------------------------------------------------------------
# Build eudev (standalone udev — provides libudev + udevd)
# ------------------------------------------------------------------
build_eudev() {
    log_step "Building eudev..."
    cd "${SOURCES_DIR}/eudev-${EUDEV_VERSION}"

    local build_dir="${SOURCES_DIR}/eudev-${EUDEV_VERSION}/build"
    rm -rf "$build_dir"

    meson setup "$build_dir" \
        --prefix=/usr \
        --libdir=lib \
        --buildtype=release \
        -Db_ndebug=true \
        -Dkmod=false \
        -Dselinux=false \
        -Dblkid=false \
        -Dman-pages=false \
        -Dhwdb=false \
        -Dtests=false 2>&1 | while IFS= read -r line; do
            echo "  meson: $line"
        done

    ninja -j"${JOBS}" -C "$build_dir" 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qiE "(error|warning|FAILED)"; then
            echo "  $line"
        fi
    done

    DESTDIR="$STAGING_DIR" ninja -C "$build_dir" install 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qiE "(error|warning)"; then
            echo "  $line"
        fi
    done

    cd "$SCRIPT_DIR"
    log_info "eudev built and installed to staging."
}

# ------------------------------------------------------------------
# Build libinput (input device handling)
# ------------------------------------------------------------------
build_libinput() {
    meson_build "libinput" \
        "${SOURCES_DIR}/libinput-${LIBINPUT_VERSION}" \
        "-Dudev=true -Dlibwacom=false -Ddebug-gui=false -Ddocumentation=false -Dtests=false"
}

# ------------------------------------------------------------------
# Build weston (Wayland compositor + desktop shell)
# ------------------------------------------------------------------
build_weston() {
    meson_build "weston" \
        "${SOURCES_DIR}/weston-${WESTON_VERSION}" \
        "-Drenderer-gl=false -Dbackend-drm=true -Dbackend-fbdev=false -Dbackend-headless=false -Dbackend-wayland=false -Dbackend-x11=false -Dbackend-rdp=false -Dbackend-vnc=false -Dpipewire=false -Dremoting=false -Dshell-desktop=true -Dshell-kiosk=false -Dshell-ivi=false -Dxwayland=false -Dweston-launch=false -Dcolor-management-lcms=false -Ddeprecated-launcher-api=true -Dlauncher-udev=true -Dlauncher-logind=false -Ddemo-clients=false -Dsimple-clients= -Dtools=calibrator,info,terminal -Dtests=false -Ddocumentation=false -Dimage-jpeg=false -Dimage-webp=false"
}

# ------------------------------------------------------------------
# Copy built libraries from staging to rootfs
# ------------------------------------------------------------------
install_to_rootfs() {
    log_step "Installing Wayland/Weston to rootfs..."

    # Copy all libraries
    mkdir -p "${ROOTFS_DIR}/usr/lib"
    cp -a "${STAGING_DIR}/usr/lib/"* "${ROOTFS_DIR}/usr/lib/" 2>/dev/null || true

    # Copy binaries
    mkdir -p "${ROOTFS_DIR}/usr/bin"
    cp -a "${STAGING_DIR}/usr/bin/"* "${ROOTFS_DIR}/usr/bin/" 2>/dev/null || true

    # Copy libexec (weston-desktop-shell, etc.)
    mkdir -p "${ROOTFS_DIR}/usr/libexec"
    cp -a "${STAGING_DIR}/usr/libexec/"* "${ROOTFS_DIR}/usr/libexec/" 2>/dev/null || true

    # Copy includes (needed for building against wayland)
    mkdir -p "${ROOTFS_DIR}/usr/include"
    cp -a "${STAGING_DIR}/usr/include/"* "${ROOTFS_DIR}/usr/include/" 2>/dev/null || true

    # Copy pkgconfig files
    mkdir -p "${ROOTFS_DIR}/usr/lib/pkgconfig"
    cp -a "${STAGING_DIR}/usr/lib/pkgconfig/"* "${ROOTFS_DIR}/usr/lib/pkgconfig/" 2>/dev/null || true
    mkdir -p "${ROOTFS_DIR}/usr/share/pkgconfig"
    cp -a "${STAGING_DIR}/usr/share/pkgconfig/"* "${ROOTFS_DIR}/usr/share/pkgconfig/" 2>/dev/null || true

    # Copy udev rules and hwdb
    if [[ -d "${STAGING_DIR}/etc/udev" ]]; then
        mkdir -p "${ROOTFS_DIR}/etc/udev"
        cp -a "${STAGING_DIR}/etc/udev/"* "${ROOTFS_DIR}/etc/udev/" 2>/dev/null || true
    fi
    if [[ -d "${STAGING_DIR}/usr/lib/udev" ]]; then
        mkdir -p "${ROOTFS_DIR}/usr/lib/udev"
        cp -a "${STAGING_DIR}/usr/lib/udev/"* "${ROOTFS_DIR}/usr/lib/udev/" 2>/dev/null || true
    fi

    # Strip shared libraries to save space
    log_step "Stripping libraries..."
    find "${ROOTFS_DIR}/usr/lib" -name "*.so*" -exec strip --strip-unneeded {} \; 2>/dev/null || true

    # Show sizes
    local weston_size
    weston_size="$(du -h "${ROOTFS_DIR}/usr/bin/weston" 2>/dev/null | cut -f1 || echo "N/A")"
    local libs_size
    libs_size="$(du -sh "${ROOTFS_DIR}/usr/lib" 2>/dev/null | cut -f1 || echo "N/A")"

    log_info "Weston binary size: ${weston_size}"
    log_info "Libraries size:     ${libs_size}"
}

# ------------------------------------------------------------------
# Print summary
# ------------------------------------------------------------------
print_summary() {
    echo ""
    echo "=============================================="
    echo "  ChaldOS Wayland Stack Build Complete"
    echo "=============================================="
    echo "  libdrm:         ${LIBDRM_VERSION}"
    echo "  wayland:        ${WAYLAND_VERSION}"
    echo "  wayland-protos: ${WPROTO_VERSION}"
    echo "  pixman:         ${PIXMAN_VERSION}"
    echo "  libxkbcommon:   ${XKBCOMMON_VERSION}"
    echo "  eudev:          ${EUDEV_VERSION}"
    echo "  libinput:       ${LIBINPUT_VERSION}"
    echo "  weston:         ${WESTON_VERSION}"
    echo "-------------------------------"
    echo "  Staging:  ${STAGING_DIR}"
    echo "  RootFS:   ${ROOTFS_DIR}"
    echo "  Parallel: ${JOBS}"
    echo "=============================================="
    echo ""
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
main() {
    parse_args "$@"

    echo "=============================================="
    echo "  ChaldOS Wayland Stack Builder"
    echo "=============================================="
    echo "  Sources: ${SOURCES_DIR}"
    echo "  Target:  ${ROOTFS_DIR}"
    echo "=============================================="
    echo ""

    check_prereqs
    prepare_dirs

    # Build in dependency order
    build_libdrm
    build_wayland
    build_wayland_protocols
    build_pixman
    build_libxkbcommon
    build_eudev
    build_libinput
    build_weston

    install_to_rootfs
    print_summary

    trap - EXIT ERR
}

main "$@"
