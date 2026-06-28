#!/bin/bash
#
# build-rootfs.sh
# Assemble the ChaldOS root filesystem:
#   - Create device nodes
#   - Set up directory structure
#   - Copy BusyBox installation
#   - Copy ChaldOS-specific overlay from rootfs/
#   - Set up init scripts and configuration
#
# Usage: ./build-rootfs.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}}"
BUILD_DIR="${BUILD_DIR:-${OUTPUT_DIR}/build}"
ROOTFS_DIR="${ROOTFS_DIR:-${BUILD_DIR}/rootfs}"
OVERLAY_DIR="${OVERLAY_DIR:-${PROJECT_DIR}/rootfs}"
CONFIG_DIR="${PROJECT_DIR}/config"

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
    log_warn "RootFS assembly interrupted or exited with error."
}
trap cleanup EXIT ERR

# ------------------------------------------------------------------
# Check prerequisites
# ------------------------------------------------------------------
check_prerequisites() {
    log_step "Checking prerequisites..."

    if [[ ! -d "${ROOTFS_DIR}" ]]; then
        log_error "RootFS directory ${ROOTFS_DIR} does not exist."
        log_error "Run build-busybox.sh first to create it."
        exit 1
    fi

    if [[ ! -f "${ROOTFS_DIR}/bin/busybox" ]]; then
        log_error "BusyBox not found in rootfs. Run build-busybox.sh first."
        exit 1
    fi

    # Check for essential tools (we need to be able to create device nodes)
    if [[ ! -e "/dev/null" ]]; then
        log_warn "/dev/null not found. Device nodes will be created but may not work."
    fi

    log_info "All prerequisites met."
}

# ------------------------------------------------------------------
# Create root filesystem directory structure
# ------------------------------------------------------------------
create_directory_structure() {
    log_step "Creating directory structure..."

    local directories=(
        "${ROOTFS_DIR}/dev"
        "${ROOTFS_DIR}/proc"
        "${ROOTFS_DIR}/sys"
        "${ROOTFS_DIR}/tmp"
        "${ROOTFS_DIR}/run"
        "${ROOTFS_DIR}/var/log"
        "${ROOTFS_DIR}/var/lock"
        "${ROOTFS_DIR}/var/run"
        "${ROOTFS_DIR}/var/tmp"
        "${ROOTFS_DIR}/var/spool"
        "${ROOTFS_DIR}/var/lib"
        "${ROOTFS_DIR}/etc/init.d"
        "${ROOTFS_DIR}/etc/network"
        "${ROOTFS_DIR}/etc/network/if-down.d"
        "${ROOTFS_DIR}/etc/network/if-post-down.d"
        "${ROOTFS_DIR}/etc/network/if-pre-up.d"
        "${ROOTFS_DIR}/etc/network/if-up.d"
        "${ROOTFS_DIR}/etc/udhcpc"
        "${ROOTFS_DIR}/etc/default"
        "${ROOTFS_DIR}/etc/ssl"
        "${ROOTFS_DIR}/etc/cron"
        "${ROOTFS_DIR}/home"
        "${ROOTFS_DIR}/root"
        "${ROOTFS_DIR}/mnt"
        "${ROOTFS_DIR}/opt"
        "${ROOTFS_DIR}/srv"
        "${ROOTFS_DIR}/usr/share/udhcpc"
    )

    for dir in "${directories[@]}"; do
        mkdir -p "${dir}"
    done

    # Set proper permissions
    chmod 1777 "${ROOTFS_DIR}/tmp"
    chmod 1777 "${ROOTFS_DIR}/var/tmp"
    chmod 0700 "${ROOTFS_DIR}/root"
    chmod 0755 "${ROOTFS_DIR}/var/log"

    log_info "Directory structure created."
}

# ------------------------------------------------------------------
# Create device nodes
# ------------------------------------------------------------------
create_device_nodes() {
    log_step "Creating device nodes..."

    # We use mknod to create essential device nodes.
    # These are the minimum needed for a working system.

    # Check if running as root (needed for mknod with major/minor numbers)
    if [[ $EUID -ne 0 ]]; then
        log_warn "Not running as root. Device nodes will be created but may have wrong permissions."
        log_warn "Run with sudo if device nodes don't work properly."
    fi

    # Standard device nodes
    mknod -m 0666 "${ROOTFS_DIR}/dev/null"     c 1 3 2>/dev/null || true
    mknod -m 0666 "${ROOTFS_DIR}/dev/zero"     c 1 5 2>/dev/null || true
    mknod -m 0666 "${ROOTFS_DIR}/dev/random"   c 1 8 2>/dev/null || true
    mknod -m 0666 "${ROOTFS_DIR}/dev/urandom"  c 1 9 2>/dev/null || true
    mknod -m 0666 "${ROOTFS_DIR}/dev/full"     c 1 7 2>/dev/null || true
    mknod -m 0666 "${ROOTFS_DIR}/dev/tty"      c 5 0 2>/dev/null || true
    mknod -m 0600 "${ROOTFS_DIR}/dev/console"  c 5 1 2>/dev/null || true
    mknod -m 0666 "${ROOTFS_DIR}/dev/ptmx"     c 5 2 2>/dev/null || true
    mknod -m 0666 "${ROOTFS_DIR}/dev/kmsg"     c 1 11 2>/dev/null || true

    # Serial ports
    mknod -m 0660 "${ROOTFS_DIR}/dev/tty0"     c 4 0 2>/dev/null || true
    mknod -m 0660 "${ROOTFS_DIR}/dev/tty1"     c 4 1 2>/dev/null || true
    mknod -m 0660 "${ROOTFS_DIR}/dev/tty2"     c 4 2 2>/dev/null || true
    mknod -m 0660 "${ROOTFS_DIR}/dev/tty3"     c 4 3 2>/dev/null || true
    mknod -m 0660 "${ROOTFS_DIR}/dev/tty4"     c 4 4 2>/dev/null || true
    mknod -m 0660 "${ROOTFS_DIR}/dev/tty5"     c 4 5 2>/dev/null || true
    mknod -m 0660 "${ROOTFS_DIR}/dev/tty6"     c 4 6 2>/dev/null || true
    mknod -m 0660 "${ROOTFS_DIR}/dev/ttyS0"    c 4 64 2>/dev/null || true
    mknod -m 0660 "${ROOTFS_DIR}/dev/ttyS1"    c 4 65 2>/dev/null || true

    # Loop devices
    for i in $(seq 0 7); do
        mknod -m 0660 "${ROOTFS_DIR}/dev/loop${i}" b 7 "${i}" 2>/dev/null || true
    done

    # Create /dev/pts directory for pseudo-terminals
    mkdir -p "${ROOTFS_DIR}/dev/pts"
    mkdir -p "${ROOTFS_DIR}/dev/shm"

    log_info "Device nodes created."
}

# ------------------------------------------------------------------
# Create etc/inittab for BusyBox init
# ------------------------------------------------------------------
create_inittab() {
    log_step "Creating /etc/inittab..."

    cat > "${ROOTFS_DIR}/etc/inittab" << 'INITTAB'
# /etc/inittab - BusyBox init configuration for ChaldOS

# When the system starts, run the startup script
::sysinit:/etc/init.d/rcS

# Mount /proc, /sys, and /dev/pts early
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t sysfs sysfs /sys
::sysinit:/bin/mount -t devtmpfs devtmpfs /dev
::sysinit:/bin/mkdir -p /dev/pts
::sysinit:/bin/mount -t devpts devpts /dev/pts
::sysinit:/bin/mount -t tmpfs tmpfs /run

# Start syslogd and klogd
::sysinit:/sbin/syslogd
::sysinit:/sbin/klogd

# Run mdev to create device nodes
::sysinit:/sbin/mdev -s

# Set hostname
::sysinit:/bin/hostname -F /etc/hostname

# Configure loopback interface
::sysinit:/sbin/ifconfig lo 127.0.0.1 up

# Start shell on the main console
::respawn:-/bin/sh

# Start shells on tty1-tty6
tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6

# What to do when Ctrl-Alt-Del is pressed
::ctrlaltdel:/sbin/reboot

# What to do when the system shuts down
::shutdown:/bin/umount -a -r
::shutdown:/sbin/swapoff -a
INITTAB

    log_info "Created /etc/inittab"
    chmod 0644 "${ROOTFS_DIR}/etc/inittab"
}

# ------------------------------------------------------------------
# Create init scripts
# ------------------------------------------------------------------
create_init_scripts() {
    log_step "Creating init scripts..."

    # Create rcS startup script
    cat > "${ROOTFS_DIR}/etc/init.d/rcS" << 'RCS'
#!/bin/sh
#
# /etc/init.d/rcS - ChaldOS system initialization script
#

echo "ChaldOS Linux - Starting system..."

# Remount root filesystem as read-write if applicable
# (For initramfs-based systems, rootfs is already writable)

# Set default PATH
export PATH="/sbin:/bin:/usr/sbin:/usr/bin"

# Configure kernel parameters
echo "Setting kernel parameters..."
sysctl -w kernel.hostname=chaldos 2>/dev/null || true

# Start device detection
echo "Starting device detection..."
/sbin/mdev -s

# Load modules listed in /etc/modules
if [ -f /etc/modules ]; then
    echo "Loading kernel modules..."
    while read -r module; do
        case "$module" in
            ""|"#"*)
                continue
                ;;
            *)
                /sbin/modprobe "$module" 2>/dev/null || echo "  Failed to load: $module"
                ;;
        esac
    done < /etc/modules
fi

# Run network configuration
if [ -x /etc/init.d/network ]; then
    echo "Configuring network..."
    /etc/init.d/network start
fi

# Set system clock (if hardware clock available)
if [ -x /sbin/hwclock ]; then
    /sbin/hwclock -s 2>/dev/null || true
fi

echo "ChaldOS Linux - System ready."
RCS

    chmod 0755 "${ROOTFS_DIR}/etc/init.d/rcS"

    # Create network init script
    cat > "${ROOTFS_DIR}/etc/init.d/network" << 'NETWORK'
#!/bin/sh
#
# /etc/init.d/network - Network configuration script
#

start() {
    echo "Starting network..."

    # Bring up loopback
    /sbin/ifconfig lo 127.0.0.1 up

    # Attempt DHCP on all Ethernet interfaces
    for iface in /sys/class/net/eth* /sys/class/net/enp* /sys/class/net/wlan*; do
        [ -e "$iface" ] || continue
        iface_name="$(basename "$iface")"
        echo "  Bringing up ${iface_name} via DHCP..."
        /sbin/udhcpc -i "${iface_name}" -b -s /usr/share/udhcpc/default.script 2>/dev/null &
    done
}

stop() {
    echo "Stopping network..."

    for iface in /sys/class/net/eth* /sys/class/net/enp* /sys/class/net/wlan*; do
        [ -e "$iface" ] || continue
        iface_name="$(basename "$iface")"
        /sbin/ifconfig "${iface_name}" down 2>/dev/null || true
    done
}

case "${1:-}" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
NETWORK

    chmod 0755 "${ROOTFS_DIR}/etc/init.d/network"

    # Create udhcpc default script
    cat > "${ROOTFS_DIR}/usr/share/udhcpc/default.script" << 'UDHCPC'
#!/bin/sh
#
# udhcpc default script for ChaldOS
#

RESOLV_CONF="/etc/resolv.conf"

case "$1" in
    deconfig)
        /sbin/ifconfig "$interface" 0.0.0.0
        ;;

    bound|renew)
        /sbin/ifconfig "$interface" "$ip" \
            ${subnet:+netmask $subnet} \
            ${broadcast:+broadcast $broadcast}

        if [ -n "$router" ]; then
            while /sbin/route del default gw 0.0.0.0 dev "$interface" 2>/dev/null; do
                :
            done

            for gw in $router; do
                /sbin/route add default gw "$gw" dev "$interface"
            done
        fi

        # Update resolver
        echo -n > "$RESOLV_CONF"
        for dns in $dns; do
            echo "nameserver $dns" >> "$RESOLV_CONF"
        done

        echo "DHCP: $interface bound to $ip"
        ;;
esac
UDHCPC

    chmod 0755 "${ROOTFS_DIR}/usr/share/udhcpc/default.script"

    log_info "Init scripts created."
}

# ------------------------------------------------------------------
# Create system configuration files
# ------------------------------------------------------------------
create_config_files() {
    log_step "Creating system configuration files..."

    # /etc/fstab
    cat > "${ROOTFS_DIR}/etc/fstab" << 'FSTAB'
# /etc/fstab - ChaldOS filesystem table
proc            /proc           proc    defaults        0 0
sysfs           /sys            sysfs   defaults        0 0
devtmpfs        /dev            devtmpfs defaults      0 0
devpts          /dev/pts        devpts  defaults        0 0
tmpfs           /run            tmpfs   defaults        0 0
tmpfs           /tmp            tmpfs   defaults        0 0
FSTAB

    # /etc/hostname
    echo "chaldos" > "${ROOTFS_DIR}/etc/hostname"

    # /etc/hosts
    cat > "${ROOTFS_DIR}/etc/hosts" << 'HOSTS'
127.0.0.1   localhost chaldos
::1         localhost ip6-localhost ip6-loopback
HOSTS

    # /etc/resolv.conf (stub, will be overwritten by DHCP)
    cat > "${ROOTFS_DIR}/etc/resolv.conf" << 'RESOLV'
# Generated by ChaldOS network configuration
nameserver 8.8.8.8
nameserver 1.1.1.1
RESOLV

    # /etc/passwd
    cat > "${ROOTFS_DIR}/etc/passwd" << 'PASSWD'
root:x:0:0:root:/root:/bin/sh
bin:x:1:1:bin:/bin:/sbin/nologin
daemon:x:2:2:daemon:/sbin:/sbin/nologin
nobody:x:65534:65534:nobody:/home:/sbin/nologin
PASSWD

    # /etc/group
    cat > "${ROOTFS_DIR}/etc/group" << 'GROUP'
root:x:0:root
bin:x:1:root,bin,daemon
daemon:x:2:root,bin,daemon
sys:x:3:root,bin
adm:x:4:root,daemon
tty:x:5:
disk:x:6:root
lp:x:7:daemon
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
kmem:x:15:
dialout:x:20:
fax:x:21:
voice:x:22:
cdrom:x:24:
floppy:x:25:
tape:x:26:
sudo:x:27:
audio:x:29:
nobody:x:65534:
GROUP

    # /etc/shadow (root with empty password for development)
    cat > "${ROOTFS_DIR}/etc/shadow" << 'SHADOW'
root::19000:0:99999:7:::
bin:*:19000:0:99999:7:::
daemon:*:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
SHADOW
    chmod 0600 "${ROOTFS_DIR}/etc/shadow"

    # /etc/default/udhcpc
    cat > "${ROOTFS_DIR}/etc/default/udhcpc" << 'UDHCPC_DEF'
# udhcpc defaults
INTERFACES="eth0 enp0s3 enp0s8 wlan0"
DHCP_SCRIPT="/usr/share/udhcpc/default.script"
UDHCPC_DEF

    # /etc/modules (kernel modules to load at boot)
    cat > "${ROOTFS_DIR}/etc/modules" << 'MODULES'
# Kernel modules to load at boot
# Network drivers
# e1000
# e1000e
# igb
# r8169
# xhci_hcd

# Filesystem support
# ext4
# squashfs
MODULES

    # /etc/profile
    cat > "${ROOTFS_DIR}/etc/profile" << 'PROFILE'
# /etc/profile - system-wide shell profile for ChaldOS

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin"
export HOME="/root"
export PS1='\u@\h:\w\$ '
export EDITOR="vi"
export PAGER="more"

# Set terminal type if not set
if [ -z "$TERM" ]; then
    export TERM="linux"
fi

# Aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias df='df -h'
alias du='du -h'
alias free='free -m'
alias grep='grep --color=auto'
PROFILE

    # /etc/issue (login prompt)
    cat > "${ROOTFS_DIR}/etc/issue" << 'ISSUE'
Welcome to ChaldOS Linux!
Kernel \r on an \m

ISSUE

    # /etc/issue.net
    cat > "${ROOTFS_DIR}/etc/issue.net" << 'ISSUENET'
Welcome to ChaldOS Linux
ISSUENET

    # /etc/nsswitch.conf
    cat > "${ROOTFS_DIR}/etc/nsswitch.conf" << 'NSSWITCH'
# /etc/nsswitch.conf
passwd:    files
shadow:    files
group:     files
hosts:     files dns
networks:  files
protocols: files
services:  files
ethers:    files
rpc:       files
netgroup:  files
NSSWITCH

    log_info "System configuration files created."
}

# ------------------------------------------------------------------
# Copy ChaldOS overlay files
# ------------------------------------------------------------------
copy_overlay() {
    log_step "Copying ChaldOS overlay files..."

    if [[ -d "${OVERLAY_DIR}" ]]; then
        # Remove hidden files and directories (like .gitkeep) from the find
        local overlay_files
        overlay_files="$(find "${OVERLAY_DIR}" -mindepth 1 -not -path '*/\.*' 2>/dev/null || true)"

        if [[ -n "$overlay_files" ]]; then
            # Use cp -a to preserve permissions and structure
            cp -a "${OVERLAY_DIR}"/* "${ROOTFS_DIR}/" 2>/dev/null || {
                # If the overlay is empty or has only hidden files, that's okay
                log_info "  (Overlay directory is empty or contains only hidden files)"
            }
            log_info "Overlay files copied."
        else
            log_info "Overlay directory is empty, nothing to copy."
        fi
    else
        log_info "No overlay directory at ${OVERLAY_DIR}, skipping."
    fi
}

# ------------------------------------------------------------------
# Copy ChaldOS pixel wallpapers
# ------------------------------------------------------------------
copy_wallpapers() {
    log_step "Copying ChaldOS pixel wallpapers..."

    mkdir -p "${ROOTFS_DIR}/usr/share/wallpapers"

    local wp_src="${PROJECT_DIR}/wallpapers"
    local wp_count=0

    if [[ -d "$wp_src" ]]; then
        for wp in "${wp_src}"/chaldos_*.png; do
            if [[ -f "$wp" ]]; then
                cp -f "$wp" "${ROOTFS_DIR}/usr/share/wallpapers/"
                wp_count=$((wp_count + 1))
            fi
        done
    fi

    if [[ $wp_count -gt 0 ]]; then
        log_info "Copied ${wp_count} wallpapers to /usr/share/wallpapers/"
    else
        log_warn "No wallpapers found at ${wp_src}"
    fi
}

# ------------------------------------------------------------------
# Set permissions and ownership
# ------------------------------------------------------------------
set_permissions() {
    log_step "Setting file permissions..."

    # Set suid bits on critical binaries
    if [[ -f "${ROOTFS_DIR}/bin/busybox" ]]; then
        # The busybox binary handles suid internally via config
        :
    fi

    # Ensure certain scripts are executable
    chmod 0755 "${ROOTFS_DIR}/etc/init.d/rcS" 2>/dev/null || true
    chmod 0755 "${ROOTFS_DIR}/etc/init.d/network" 2>/dev/null || true
    chmod 0755 "${ROOTFS_DIR}/usr/share/udhcpc/default.script" 2>/dev/null || true

    # Set proper directory permissions
    chmod 1777 "${ROOTFS_DIR}/tmp" 2>/dev/null || true
    chmod 1777 "${ROOTFS_DIR}/var/tmp" 2>/dev/null || true

    log_info "Permissions set."
}

# ------------------------------------------------------------------
# Print summary
# ------------------------------------------------------------------
print_summary() {
    local rootfs_size
    rootfs_size="$(du -sh "${ROOTFS_DIR}" 2>/dev/null | cut -f1)"

    local file_count
    file_count="$(find "${ROOTFS_DIR}" -type f 2>/dev/null | wc -l)"

    echo ""
    echo "=============================================="
    echo "  ChaldOS RootFS Assembly Complete"
    echo "=============================================="
    echo "  RootFS size:  ${rootfs_size}"
    echo "  Files:        ${file_count}"
    echo "  Location:     ${ROOTFS_DIR}"
    echo "=============================================="
    echo ""
}

# ------------------------------------------------------------------
# Main script execution
# ------------------------------------------------------------------
main() {
    echo "=============================================="
    echo "  ChaldOS RootFS Builder"
    echo "=============================================="
    echo "  RootFS:    ${ROOTFS_DIR}"
    echo "  Overlay:   ${OVERLAY_DIR}"
    echo "=============================================="
    echo ""

    check_prerequisites
    create_directory_structure
    create_device_nodes
    create_inittab
    create_init_scripts
    create_config_files
    copy_overlay
    copy_wallpapers
    set_permissions
    print_summary

    trap - EXIT ERR
}

main "$@"
