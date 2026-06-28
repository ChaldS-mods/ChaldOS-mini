# ChaldOS Command Reference

## System Commands

### `help`
Display the full command reference.

```
help
```

### `chaldos-info`
Display detailed system information.

```
chaldos-info
```

Example output:
```
═══ ChaldOS System Information ═══
 OS:       ChaldOS 1.0.0 "Pixel Dawn"
 Kernel:   Linux 6.6.30-chaldos
 Arch:     x86_64
 Uptime:   2h 15m
 CPU:      Intel(R) Core(TM) i7-8700K (12 cores)
 Memory:   15796M total / 3241M used / 12555M free
 Displays: fb0: 1920,1080 @32bpp
```

### `chaldos-config`
Configure system settings.

```bash
# Show current config
chaldos-config show

# Set hostname
chaldos-config hostname my-chaldos

# Set a key-value
chaldos-config set wallpaper chaldos_night

# Reset to defaults
chaldos-config reset
```

### `chaldos-wallpaper`
Set desktop wallpaper.

```bash
# List available wallpapers
chaldos-wallpaper list

# Set wallpaper
chaldos-wallpaper set chaldos_night

# Show current
chaldos-wallpaper current

# Short form
chaldos-wallpaper chaldos_forest
```

### `chaldos-update`
Check for system updates online.

```
chaldos-update
```

### `monitor-config`
Configure multi-monitor displays.

```bash
# Detect and list displays
monitor-config detect
monitor-config list

# Set resolution (fbset required)
monitor-config setmode fb0 1920x1080
monitor-config setmode fb1 1680x1050
```

## File Commands

| Command | Description | Example |
|---------|-------------|---------|
| `ls` | List directory | `ls -la /home` |
| `cd` | Change directory | `cd /etc` |
| `pwd` | Print working dir | `pwd` |
| `cp` | Copy files | `cp file1 file2` |
| `mv` | Move/rename | `mv old new` |
| `rm` | Remove files | `rm -rf dir` |
| `mkdir` | Create directory | `mkdir -p a/b/c` |
| `cat` | Display file | `cat /proc/cpuinfo` |
| `less` | View with paging | `less /var/log/syslog` |
| `head` | First lines | `head -n 20 file` |
| `tail` | Last lines | `tail -f /var/log/syslog` |
| `nano` | Text editor | `nano /etc/hostname` |
| `vi` | Advanced editor | `vi /etc/fstab` |
| `grep` | Search text | `grep "error" log.txt` |
| `find` | Find files | `find / -name "*.conf"` |
| `tar` | Archive tool | `tar -xzf archive.tar.gz` |
| `sview` | ChaldOS viewer | `sview file.txt` |

## Network Commands

| Command | Description | Example |
|---------|-------------|---------|
| `wget` | Download file | `wget https://example.com/file` |
| `curl` | Transfer data | `curl -O https://example.com/file` |
| `fetch` | ChaldOS download | `fetch https://example.com/file` |
| `ping` | Test connectivity | `ping -c 4 google.com` |
| `ifconfig` | Interface config | `ifconfig eth0` |
| `ip` | Advanced networking | `ip addr show` |
| `dhcpcd` | DHCP client | `dhcpcd eth0` |
| `ssh` | Remote shell | `ssh user@host` (if dropbear installed) |
| `hostname` | Set hostname | `hostname my-chaldos` |

## Process Commands

| Command | Description | Example |
|---------|-------------|---------|
| `ps` | List processes | `ps aux` |
| `top` | Process monitor | `top` |
| `kill` | Kill process | `kill -9 1234` |
| `killall` | Kill by name | `killall firefox` |
| `jobs` | List background jobs | `jobs` |
| `bg` | Background a job | `bg %1` |
| `fg` | Foreground a job | `fg %1` |

## System Control

| Command | Description | Example |
|---------|-------------|---------|
| `reboot` | Reboot system | `reboot` |
| `poweroff` | Shutdown | `poweroff` |
| `dmesg` | Kernel messages | `dmesg | tail` |
| `modprobe` | Load module | `modprobe i915` |
| `lsmod` | List modules | `lsmod` |
| `mount` | Mount filesystem | `mount /dev/sdb1 /mnt` |
| `umount` | Unmount | `umount /mnt` |
| `df` | Disk space | `df -h` |
| `du` | File sizes | `du -sh /home/*` |
| `free` | Memory usage | `free -h` |
| `uname` | Kernel info | `uname -a` |
| `uptime` | System uptime | `uptime` |
| `dmesg` | Kernel log | `dmesg -w` |

## ChaldOS Custom Commands

### `fetch <url> [filename]`
Download a file with progress indication. Wraps wget/curl.

```
fetch https://example.com/file.tar.gz
fetch https://example.com/file.tar.gz output.tar.gz
```

### `mkchaldos <name>`
Create a new ChaldOS-style project directory.

```
mkchaldos my-project
cd my-project
make run
```

### `sview <file>`
View a file with ChaldOS-styled header showing file info.

```
sview /etc/hostname
sview /var/log/syslog
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `EDITOR` | `vi` | Default text editor |
| `PAGER` | `less` | Default pager |
| `PS1` | custom | Shell prompt |
| `PATH` | standard | Executable search path |

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Tab` | Auto-complete command |
| `↑ ↓` | Command history |
| `Ctrl+C` | Interrupt current command |
| `Ctrl+D` | Exit shell (EOF) |
| `Ctrl+L` | Clear screen |
| `Ctrl+Z` | Suspend current job |
| `Ctrl+A` | Go to line start |
| `Ctrl+E` | Go to line end |
| `Ctrl+W` | Delete word backwards |
| `Ctrl+U` | Delete whole line |
| `Ctrl+R` | Reverse search history |
