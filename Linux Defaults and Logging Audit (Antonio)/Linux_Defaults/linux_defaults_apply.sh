#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${CONF_FILE:-$ROOT/linux_defaults.conf}"

MODE="audit"
YES="no"

for arg in "$@"; do
  case "$arg" in
    --apply) MODE="apply" ;;
    --audit) MODE="audit" ;;
    --yes|-y) YES="yes" ;;
    --conf=*) CONF_FILE="${arg#*=}" ;;
  esac
done

log(){ echo "[*] $*"; }
warn(){ echo "[!] $*" >&2; }
die(){ echo "[x] $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
ts(){ date +%Y%m%d%H%M%S; }

[[ "$(id -u)" -eq 0 ]] || die "Run as root."

detect_distro(){
  source /etc/os-release 2>/dev/null || true
  OS_NAME="${PRETTY_NAME:-unknown}"
}

source "$CONF_FILE"

REPORT_DIR="${REPORT_DIR:-/var/log/ccdc-linux-defaults}"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/linux_defaults.$(hostname).$(ts).log"

record(){ echo "$(date -Is) $*" | tee -a "$REPORT_FILE" >/dev/null; }
section(){ record "==================== $* ===================="; }

confirm_apply(){
  [[ "$MODE" == "apply" ]] || return
  [[ "$YES" == "yes" ]] && return
  read -rp "Type YES to apply baseline changes: " ans
  [[ "$ans" == "YES" ]] || die "Aborted."
}

backup_file(){
  [[ -f "$1" ]] && cp -a "$1" "$1.bak.$(ts)"
}

run_cmd(){
  local d="$1"; shift
  if [[ "$MODE" == "apply" ]]; then
    record "APPLY: $d"
    "$@" >> "$REPORT_FILE" 2>&1 || warn "FAILED: $*"
  else
    record "AUDIT: would $d"
  fi
}

fix_sensitive_file_perms(){
section "Sensitive perms"

[[ -f /etc/passwd ]] && run_cmd "chmod passwd" chmod 644 /etc/passwd
[[ -f /etc/group ]] && run_cmd "chmod group" chmod 644 /etc/group

shadow_grp="root"
getent group shadow >/dev/null && shadow_grp="shadow"

[[ -f /etc/shadow ]] && run_cmd "chmod shadow" chmod 640 /etc/shadow
[[ -f /etc/gshadow ]] && run_cmd "chmod gshadow" chmod 640 /etc/gshadow
[[ -f /etc/sudoers ]] && run_cmd "chmod sudoers" chmod 440 /etc/sudoers
}

set_umask(){
section "Umask"

target="/etc/profile.d/99-ccdc-umask.sh"
[[ -f "$target" ]] && backup_file "$target"

[[ "$MODE" == "apply" ]] \
  && printf "umask %s\n" "$UMASK_VALUE" > "$target" \
  || record "AUDIT would write umask $UMASK_VALUE"
}

fix_tmp(){
section "Tmp perms"
for d in "${TMP_DIRS[@]}"; do
  [[ -d "$d" ]] && run_cmd "chmod 1777 $d" chmod 1777 "$d"
done
}

disable_core(){
section "Disable core dumps"

file="/etc/security/limits.d/99-ccdc-core.conf"
[[ -f "$file" ]] && backup_file "$file"

[[ "$MODE" == "apply" ]] \
 && echo "* hard core 0" > "$file" \
 || record "AUDIT would disable core dumps"
}

apply_sysctl(){
section "Kernel hardening"

file="/etc/sysctl.d/99-ccdc-local-hardening.conf"
[[ -f "$file" ]] && backup_file "$file"

if [[ "$MODE" == "apply" ]]; then
cat > "$file" <<EOF
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.randomize_va_space = 2
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.suid_dumpable = 0
EOF
sysctl --system >> "$REPORT_FILE" 2>&1
else
record "AUDIT would apply kernel sysctls"
fi
}

selinux_apply(){
section "SELinux"

command -v getenforce >/dev/null || return
state="$(getenforce)"

record "Current=$state"

[[ "$SELINUX_SET_ENFORCING" != "yes" ]] && return

[[ "$state" == "Permissive" ]] && run_cmd "setenforce 1" setenforce 1
}

confirm_apply
detect_distro

fix_sensitive_file_perms
set_umask
fix_tmp
disable_core
apply_sysctl
selinux_apply

section "DONE"
echo "[*] Report: $REPORT_FILE"
tail -n 40 "$REPORT_FILE"
