#!/usr/bin/env bash
# Hardware / OS detection. Sets DET_* variables; never changes the system.

detect_all() {
  . /etc/os-release 2>/dev/null || true
  DET_OS_ID="${ID:-unknown}"; DET_OS_LIKE="${ID_LIKE:-}"; DET_OS_NAME="${PRETTY_NAME:-unknown}"
  case "$DET_OS_ID $DET_OS_LIKE" in
    *ubuntu*|*debian*|*raspbian*|*fedora*) DET_OS_SUPPORTED=full ;;
    *) DET_OS_SUPPORTED=besteffort ;;
  esac
  case "$(uname -m)" in x86_64|amd64) DET_ARCH=amd64 ;; aarch64|arm64) DET_ARCH=arm64 ;; *) DET_ARCH="$(uname -m)" ;; esac
  DET_RAM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
  DET_RAM_AVAIL_MB=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
  DET_CPUS=$(nproc)
  DET_VIRT=$(systemd-detect-virt 2>/dev/null) || true; DET_VIRT=${DET_VIRT:-none}
  [ "$DET_VIRT" = none ] && DET_IS_VM=0 || DET_IS_VM=1
  [ -d /dev/dri ] && ls /dev/dri/renderD* >/dev/null 2>&1 && DET_GPU=1 || DET_GPU=0
  DET_ZIGBEE=$(ls /dev/serial/by-id/ 2>/dev/null | grep -iE 'zigbee|sonoff|conbee|skyconnect|slzb|cc2652|efr32|zbt' | head -1)
  [ -n "$DET_ZIGBEE" ] && DET_ZIGBEE="/dev/serial/by-id/$DET_ZIGBEE"
  command -v docker >/dev/null 2>&1 && DET_DOCKER=1 || DET_DOCKER=0
  DET_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo UTC)
  DET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
  DET_UID=$(id -u "$DET_USER" 2>/dev/null || echo 1000)
  DET_HOST_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
}

# Mounted filesystems with free space (real disks only): "mountpoint free_gb size_gb"
detect_disks() {
  df -BG --output=target,avail,size,fstype -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null \
    | awk 'NR>1 && $1!~/^\/(boot|snap)/ {gsub("G","",$2); gsub("G","",$3); print $1, $2, $3}'
}

# Free GB at a path (walks up to the nearest existing parent)
free_gb_at() { local p="$1"; while [ ! -e "$p" ]; do p=$(dirname "$p"); done; df -BG --output=avail "$p" | tail -1 | tr -dc 0-9; }

# Is a TCP/UDP port already bound on the host? port_in_use <port>
port_in_use() { ss -Htuln 2>/dev/null | awk '{print $5}' | grep -qE "[:.]$1\$"; }

detect_summary() {
  printf '%s\n' \
    "OS:        $DET_OS_NAME ($([ "$DET_OS_SUPPORTED" = full ] && echo supported || echo best effort))" \
    "CPU:       $DET_ARCH, $DET_CPUS cores" \
    "RAM:       $((DET_RAM_MB/1024)) GB total, $((DET_RAM_AVAIL_MB/1024)) GB free" \
    "GPU:       $([ "$DET_GPU" = 1 ] && echo 'yes (hardware transcoding)' || echo 'none found')" \
    "Zigbee:    ${DET_ZIGBEE:-none found}" \
    "Docker:    $([ "$DET_DOCKER" = 1 ] && echo installed || echo 'will be installed')" \
    "Machine:   $([ "$DET_IS_VM" = 1 ] && echo "virtual machine ($DET_VIRT)" || echo 'physical')" \
    "Address:   ${DET_HOST_IP:-unknown}"
}
