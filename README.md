# ChaldOS — Pixel Operating System

```
    ░▒▓███████████████████▓▒░
    ██                   ██
    ██  ░▒▓█ ChaldOS █▓▒░  ██
    ██                   ██
    ░▒▓███████████████████▓▒░
        ╔══════════════╗
        ║  Pixel Dawn  ║
        ╚══════════════╝
```

**ChaldOS** — minimalistic Linux distribution based on the Linux kernel.
Focused on simplicity, pixel aesthetics, and modern hardware support,
including multi-monitor setups and networking.

## ✨ Features

- 🐧 **Linux kernel 6.6 LTS** — modern, secure, efficient
- 📟 **BusyBox-based userspace** — small footprint, fast boot
- 🖥️ **Multi-monitor support** — Intel/AMD/NVIDIA KMS, Xorg configs included
- 🌐 **Full networking** — Ethernet, WiFi, DHCP, wget/curl ready
- 🎨 **Pixel wallpapers** — 7 custom pixel-art wallpapers included
- 📦 **Custom commands** — `chaldos-info`, `monitor-config`, `fetch`, and more
- 💿 **Smart installer** — full disk, dual-boot, or manual partitioning
- 🚀 **Fast boot** from initramfs to login in seconds

## 📋 Requirements

- **CPU:** x86_64 (Intel Core 2 / AMD K8 or newer)
- **RAM:** 512 MB minimum (1 GB recommended)
- **Disk:** 4 GB minimum (10 GB recommended for full install)
- **Build:** Any Linux distribution with GCC, make, and standard toolchain

## 🚀 Quick Start

### Build from source

```bash
git clone https://github.com/chaldos/os.git
cd chaldos
./build.sh
```

This will:
1. Download Linux kernel 6.6.x and BusyBox 1.36.x
2. Configure and compile with ChaldOS optimizations
3. Assemble the root filesystem with all custom tools
4. Create a bootable ISO in `output/images/`

### Install

Boot the ISO and run:

```bash
# Interactive installer
sudo install-chaldos.sh

# Automatic (entire disk)
sudo install-chaldos.sh --auto /dev/sda
```

## 🎮 Commands

| Command | Description |
|---------|-------------|
| `help` | Show command reference |
| `chaldos-info` | System information |
| `chaldos-config` | Configure system settings |
| `chaldos-wallpaper` | Set desktop wallpaper |
| `chaldos-update` | Check for updates |
| `monitor-config` | Multi-monitor setup |
| `fetch <url>` | Download a file |
| `mkchaldos <name>` | Create new ChaldOS project |

See [docs/COMMANDS.md](docs/COMMANDS.md) for full reference.

## 🖼️ Wallpapers

ChaldOS comes with 7 pixel-art wallpapers generated at 1920×1080:

| Wallpaper | Description |
|-----------|-------------|
| `chaldos_terminal` | Retro terminal with matrix rain |
| `chaldos_sunset` | Mountain sunset landscape |
| `chaldos_logo` | ChaldOS logo artwork |
| `chaldos_night` | Night sky with moon andstars |
| `chaldos_cyberpunk` | Synthwave/outrun style |
| `chaldos_forest` | Pixel forest scene |
| `chaldos_city` | Night city with neon lights |

## 🏗️ Project Structure

```
chaldos/
├── Makefile              # Build system
├── build.sh              # Build entry point
├── config/               # Configuration files
│   ├── chaldos.conf      # Build options
│   ├── kernel.config     # Linux kernel config
│   └── busybox.config    # BusyBox config
├── rootfs/               # Root filesystem overlay
│   ├── etc/              # System configuration
│   ├── usr/bin/          # Custom commands
│   └── usr/lib/          # Libraries
├── initramfs/            # Initramfs scripts
├── bootloader/           # GRUB / ISOLINUX configs
├── installer/            # Installation scripts
├── scripts/              # Build scripts
├── wallpapers/           # Pixel wallpapers
└── docs/                 # Documentation
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

## 📝 License

ChaldOS is open source software.
Linux kernel is GPLv2. BusyBox is GPLv2.

---

*Built with pixel precision. Made for the love of computing.*
