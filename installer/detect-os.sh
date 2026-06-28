#!/bin/bash
# ChaldOS — OS Detection for Dual-Boot
# ======================================
# Detects installed operating systems for dual-boot setup.

detect_windows() {
    local result=()

    # Check EFI boot entries
    if command -v efibootmgr &>/dev/null; then
        if efibootmgr -v 2>/dev/null | grep -qi "Windows"; then
            result+=("Windows (EFI boot)")
        fi
    fi

    # Check partitions for Windows files
    for part in /dev/sd*[0-9] /dev/nvme*n[0-9]p[0-9]; do
        [[ -b "$part" ]] || continue
        local tmp=$(mktemp -d)
        if mount "$part" "$tmp" 2>/dev/null; then
            if [[ -f "${tmp}/Windows/System32/winload.exe" ]]; then
                result+=("Windows ($part)")
            fi
            if [[ -d "${tmp}/Windows" ]]; then
                result+=("Windows-like system ($part)")
            fi
            umount "$tmp" 2>/dev/null || true
        fi
        rmdir "$tmp" 2>/dev/null || true
    done

    echo "${result[@]}"
}

detect_linux() {
    local result=()

    for part in /dev/sd*[0-9] /dev/nvme*n[0-9]p[0-9]; do
        [[ -b "$part" ]] || continue
        local tmp=$(mktemp -d)
        if mount "$part" "$tmp" 2>/dev/null; then
            if [[ -f "${tmp}/etc/os-release" ]]; then
                source "${tmp}/etc/os-release" 2>/dev/null || true
                result+=("${NAME:-Linux} ($part)")
            fi
            if [[ -d "${tmp}/boot" ]] && [[ -f "${tmp}/boot/vmlinuz" || -d "${tmp}/boot/grub" ]]; then
                if [[ -z "${result[*]}" ]]; then
                    result+=("Linux-based OS ($part)")
                fi
            fi
            umount "$tmp" 2>/dev/null || true
        fi
        rmdir "$tmp" 2>/dev/null || true
    done

    echo "${result[@]}"
}

detect_macos() {
    local result=()

    for part in /dev/sd*[0-9]; do
        [[ -b "$part" ]] || continue
        local fstype=$(blkid -s TYPE -o value "$part" 2>/dev/null || echo "")
        if [[ "$fstype" = "hfsplus" ]] || [[ "$fstype" = "apfs" ]]; then
            result+=("macOS ($part)")
        fi
    done

    echo "${result[@]}"
}

# Main detection
main() {
    echo "=== ChaldOS OS Detection ==="
    echo ""

    echo "Scanning for installed operating systems..."
    echo ""

    local windows=($(detect_windows))
    local linux=($(detect_linux))
    local macos=($(detect_macos))

    if [[ ${#windows[@]} -gt 0 ]]; then
        echo "Windows:"
        for w in "${windows[@]}"; do echo "  - $w"; done
    fi

    if [[ ${#linux[@]} -gt 0 ]]; then
        echo "Linux:"
        for l in "${linux[@]}"; do echo "  - $l"; done
    fi

    if [[ ${#macos[@]} -gt 0 ]]; then
        echo "macOS:"
        for m in "${macos[@]}"; do echo "  - $m"; done
    fi

    if [[ ${#windows[@]} -eq 0 ]] && [[ ${#linux[@]} -eq 0 ]] && [[ ${#macos[@]} -eq 0 ]]; then
        echo "No other operating systems detected."
        echo "Proceeding with single-boot setup."
    fi

    echo ""
    echo "Total OS found: $(( ${#windows[@]} + ${#linux[@]} + ${#macos[@]} ))"
}

main "$@"
