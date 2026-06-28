#!/bin/bash
# ChaldOS Post-Installation Script
# ==================================
# Run inside the newly installed system.

set -euo pipefail

CHALDOS_ROOT="/"

echo "=== ChaldOS Post-Installation Setup ==="
echo ""

# Create ChaldOS user
if ! id chaldos &>/dev/null; then
    useradd -m -s /bin/sh -G video,audio,network chaldos
    echo "chaldos:chaldos" | chpasswd
    echo "[OK] User 'chaldos' created"
fi

# Set up environment
echo "[OK] Setting up environment..."
echo "chaldos" > /etc/hostname

# Wallpaper directory
mkdir -p /usr/share/wallpapers

# Create initial config
if [[ ! -f /etc/chaldos.conf ]]; then
    cat > /etc/chaldos.conf << 'EOF'
# ChaldOS System Configuration
hostname=chaldos
theme=pixel-dark
wallpaper=chaldos_night
EOF
    echo "[OK] Default config created"
fi

# Logging directories
mkdir -p /var/log /var/run /var/lock
chmod 777 /var/run /var/lock

# Set permissions on binaries
chmod 755 /usr/bin/chaldos-* 2>/dev/null || true
chmod 755 /usr/bin/monitor-config 2>/dev/null || true
chmod 755 /usr/bin/fetch 2>/dev/null || true
chmod 755 /usr/bin/help 2>/dev/null || true

# Network configuration
if [[ ! -f /etc/network/interfaces ]]; then
    mkdir -p /etc/network
    cat > /etc/network/interfaces << 'EOF'
# ChaldOS network interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF
fi

echo ""
echo "ChaldOS post-installation complete!"
echo "Default login: root / chaldos"
echo "               or chaldos / chaldos"
