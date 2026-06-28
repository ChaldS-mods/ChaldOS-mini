# Installing ChaldOS

## Installation Methods

ChaldOS can be installed in three ways:

1. **Entire Disk** — Wipes the selected disk and installs ChaldOS
2. **Alongside Another OS** — Dual-boot setup (preserves existing OS)
3. **Manual Partitioning** — Expert mode for custom setups

## Requirements

- **x86_64** processor (Intel Core 2 / AMD K8 or newer)
- **4 GB** disk space minimum (10 GB recommended)
- **512 MB** RAM minimum (1 GB recommended for GUI)
- **USB stick** or **DVD** for installation media
- Boot from **USB** or **CD/DVD**

## Creating Installation Media

### From ISO

```bash
# Write to USB (Linux)
sudo dd if=chaldos-1.0.0-x86_64.iso of=/dev/sdX bs=4M status=progress

# Write to USB (Windows)
# Use Rufus, balenaEtcher, or:
C:\> dd if=chaldos-1.0.0-x86_64.iso of=\\.\d: bs=4M

# Burn to DVD
sudo wodim chaldos-1.0.0-x86_64.iso
```

## Interactive Installation

1. **Boot from the ChaldOS ISO**
2. At the boot menu, select "ChaldOS" or wait for countdown
3. After boot, log in as `root` (no password on live system)
4. Run the installer:

```bash
install-chaldos.sh
```

### Step-by-Step

#### 1. System Detection
The installer scans for:
- Connected disks and partitions
- Other operating systems (Linux, Windows, macOS)
- EFI vs BIOS boot mode

#### 2. Select Disk
```
Select target disk:
  1) /dev/sda   (256GB  SSD)
  2) /dev/sdb   (1TB    HDD)
[1-2]: 1
```

#### 3. Choose Installation Type
```
Select installation type:
  1) Use entire disk
  2) Install alongside another OS
  3) Manual partitioning

Other OS detected: Windows (/dev/sda2)
```

**Option 1 — Entire Disk:**
- Creates GPT (EFI) or MBR (BIOS) partition table
- Creates root partition with ext4
- For EFI: creates 512MB FAT32 EFI System Partition
- No partitions preserved

**Option 2 — Dual-Boot:**
- Detects existing operating systems
- Attempts to shrink existing partition
- Creates ChaldOS root partition in free space
- Configures GRUB with all OS entries

**Option 3 — Manual:**
- Opens fdisk/cfdisk for custom partitioning
- Or allows selecting existing partition
- Full control over partition layout

#### 4. Installation
Installer:
- Formats the root partition
- Copies root filesystem
- Installs kernel and initramfs
- Configures fstab with UUIDs
- Installs GRUB bootloader

#### 5. Complete
- Set root password when prompted
- Reboot and remove installation media
- Boot into ChaldOS!

## Unattended Installation

For automated deployment:

```bash
# Automatic — entire disk
install-chaldos.sh --auto /dev/sda

# Automatic — specify partition
install-chaldos.sh --auto /dev/nvme0n1
```

## Post-Installation

### First Boot

1. At the GRUB menu, select "ChaldOS"
2. Login as:
   - **Username:** `root`
   - **Password:** `chaldos`
3. Run `chaldos-info` to check your system
4. Configure network:
   ```bash
   dhcpcd eth0
   ```

### Setting Up WiFi

```bash
# Edit the config with your network credentials
wpa_passphrase "MyNetwork" "mypassword" >> /etc/wpa_supplicant/wpa_supplicant.conf

# Start WiFi
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf
dhcpcd wlan0
```

### Changing Hostname

```bash
chaldos-config hostname my-machine
```

### Setting Wallpaper

```bash
# List available
chaldos-wallpaper list

# Set it
chaldos-wallpaper set chaldos_night
```

## Dual-Boot Notes

### With Windows

1. The installer detects Windows via EFI boot entries
2. GRUB is configured with Windows boot entry
3. At GRUB menu, choose ChaldOS or Windows
4. Windows Boot Manager remains intact

### With Linux

1. The installer scans for other Linux installations
2. Existing Linux kernels are added to GRUB menu
3. GRUB from either OS can boot the other

## Troubleshooting

### Installation Fails

```bash
# Check system requirements
free -h
df -h
uname -m

# Check disk health
smartctl -a /dev/sda
```

### Boot Issues

| Symptom | Solution |
|---------|----------|
| Kernel panic | Try "Safe Mode" from boot menu |
| No display | Use "nomodeset" boot parameter |
| No network | Check cable, run `dhcpcd eth0` |
| GRUB not showing | Reinstall bootloader from live CD |

### Rescuing the System

Boot from the ChaldOS live ISO and:

```bash
# Mount installed system
mount /dev/sda1 /mnt
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

# Chroot
chroot /mnt /bin/sh

# Reinstall GRUB
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# Exit and reboot
exit
reboot
```
