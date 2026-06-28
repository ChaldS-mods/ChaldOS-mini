#!/bin/sh
# ChaldOS Shell Library
# /usr/lib/chaldos/libchaldos.sh
# Source this in your shell profile.

# ---- Colors ----
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_PURPLE='\033[0;35m'
C_WHITE='\033[1;37m'

# ---- Logging ----
chaldos_log()    { echo -e "${C_GREEN}[✓]${C_RESET} $1"; }
chaldos_warn()   { echo -e "${C_YELLOW}[!]${C_RESET} $1"; }
chaldos_error()  { echo -e "${C_RED}[✗]${C_RESET} $1"; }
chaldos_info()   { echo -e "${C_CYAN}[i]${C_RESET} $1"; }
chaldos_header() { echo -e "\n${C_BOLD}${C_CYAN}═══ $1 ═══${C_RESET}\n"; }

# ---- System Info ----
chaldos_uptime() {
    local up=$(</proc/uptime)
    up="${up%%.*}"
    local days=$((up / 86400))
    local hours=$(( (up % 86400) / 3600 ))
    local mins=$(( (up % 3600) / 60 ))
    local secs=$((up % 60))
    [[ $days -gt 0 ]] && echo -n "${days}d "
    [[ $hours -gt 0 ]] && echo -n "${hours}h "
    [[ $mins -gt 0 ]] && echo -n "${mins}m "
    echo "${secs}s"
}

chaldos_meminfo() {
    local total used free
    total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    free=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    used=$((total - free))
    echo "$((total/1024))M total / $((used/1024))M used / $((free/1024))M free"
}

chaldos_cpuinfo() {
    local model
    model=$(grep 'model name' /proc/cpuinfo | head -1 | sed 's/.*: //')
    local cores
    cores=$(grep -c ^processor /proc/cpuinfo)
    echo "${model} (${cores} cores)"
}

# ---- Utility Functions ----
chaldos_banner() {
    echo -e "${C_GREEN}"
    echo "    ░▒▓█ ChaldOS █▓▒░"
    echo -e "${C_RESET}"
}

chaldos_weather() {
    [[ -z "$1" ]] && local city="Москва" || local city="$1"
    # Simple weather fetch
    if command -v wget &>/dev/null; then
        wget -q -O- "wttr.in/${city}?format=3" 2>/dev/null || echo "Weather unavailable"
    else
        echo "Install wget for weather"
    fi
}

# ---- Package management helpers ----
chaldos_pkg_install() {
    echo "ChaldOS package management coming soon."
    echo "For now, install software from source."
}

# ---- Display helpers ----
chaldos_monitors() {
    local monitors=""
    for fb in /sys/class/graphics/fb*; do
        [[ -e "$fb" ]] || continue
        local name=$(basename "$fb")
        local res=""
        if [[ -f "${fb}/virtual_size" ]]; then
            res=$(cat "${fb}/virtual_size" 2>/dev/null)
        fi
        monitors="${monitors}  ${name}: ${res:-unknown}\n"
    done
    if [[ -z "$monitors" ]]; then
        echo "No framebuffers detected"
    else
        echo -e "Detected displays:\n${monitors}"
    fi
}
