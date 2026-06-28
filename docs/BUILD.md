# Building ChaldOS

## Prerequisites

You need a Linux system (physical or VM) with:

**Required packages:**
```bash
# Debian/Ubuntu
sudo apt install build-essential libncurses-dev bison flex libssl-dev \
    libelf-dev bc wget rsync cpio xz-utils gawk \
    squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools

# Arch Linux
sudo pacman -S base-devel ncurses bison flex openssl libelf bc wget \
    rsync cpio xz gawk squashfs-tools libisoburn grub mtools

# Fedora/RHEL
sudo dnf install gcc make ncurses-devel bison flex openssl-devel \
    elfutils-libelf-devel bc wget rsync cpio xz gawk \
    squashfs-tools xorriso grub2-pc grub2-efi-x64 mtools
```

## Build Process

### Quick Build

```bash
cd chaldos
./build.sh
```

The full build takes approximately:
- **First build:** 20-40 minutes (downloading + compiling kernel + busybox)
- **Subsequent builds:** 5-10 minutes (cached sources)

### Step-by-Step Build

```bash
# 1. Download all sources
./build.sh download

# 2. Build Linux kernel (~15 min)
./build.sh kernel

# 3. Build BusyBox (~2 min)
./build.sh busybox

# 4. Assemble root filesystem
./build.sh rootfs

# 5. Build initramfs (~1 min)
./build.sh initramfs

# 6. Create ISO
./build.sh iso

# Or use make
make iso
```

### Output Files

All build artifacts are placed in `output/`:

```
output/
├── sources/          # Downloaded source tarballs
│   ├── linux-6.6.30.tar.xz
│   └── busybox-1.36.1.tar.bz2
├── build/            # Build directories
├── images/           # Final bootable images
│   ├── vmlinuz       # Linux kernel
│   ├── initramfs.cpio.gz  # Initial RAM filesystem
│   └── chaldos-1.0.0-x86_64.iso  # Bootable ISO
└── initramfs/        # Initramfs staging
```

## Customization

### Kernel Configuration

```bash
# Modify kernel config
make menuconfig -C output/build/linux

# Or edit directly
nano config/kernel.config
```

### Add Packages

Edit `config/chaldos.conf` to add packages:

```makefile
CHALDOS_PACKAGES += \
    alsa-utils \
    bluez \
    openssh
```

### Change Wallpaper

The default wallpaper is set in `rootfs/root/.chaldosrc`:

```
wallpaper=chaldos_night
```

Available: terminal, sunset, logo, night, cyberpunk, forest, city

## Building for Different Architectures

ChaldOS supports cross-compilation. Set the target in `config/chaldos.conf`:

```makefile
BUILD_ARCH := aarch64
CROSS_COMPILE := aarch64-linux-gnu-
```

You'll need the appropriate cross-compiler toolchain installed.

## Clean Build

```bash
# Remove build artifacts (keep sources)
make clean
./build.sh clean

# Full clean (remove everything including sources)
make distclean
./build.sh distclean
```
