#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPORT_DIR="${REPORT_DIR:-/var/log/ccdc-audits}"
HOST="$(hostname 2>/dev/null || echo unknown)"
TS="$(date +%Y%m%d%H%M%S)"
REPORT_FILE="${REPORT_DIR}/audit_persist_logging.${HOST}.${TS}.log"

MAX_LINES=200
MAX_AUTH_KEYS_USERS=80

log(){ echo "[*] $*"; }
die(){ echo "[x] $*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || die "Run as root."

mkdir -p "$REPORT_DIR"
touch "$REPORT_FILE"

record(){ echo "$(date -Is) $*" >> "$REPORT_FILE"; }
section(){ record "==================== $* ===================="; }

has_cmd(){ command -v "$1" >/dev/null 2>&1; }

audit_persistence() {

section "HOST INFO"
uname -a >> "$REPORT_FILE"
uptime >> "$REPORT_FILE"

file() {
  local f="$1"
  section "$f"
  [[ -f "$f" ]] && head -n "$MAX_LINES" "$f" >> "$REPORT_FILE" || record "Missing"
}

dir() {
  local d="$1"
  section "$d"
  [[ -d "$d" ]] && ls -la "$d" | head -n "$MAX_LINES" >> "$REPORT_FILE" || record "Missing"
}

file /etc/crontab
dir /etc/cron.d
dir /etc/cron.hourly
dir /etc/cron.daily
dir /etc/cron.weekly
dir /etc/cron.monthly
dir /var/spool/cron
dir /var/spool/cron/crontabs

if has_cmd systemctl; then
  section "SYSTEMD TIMERS"
  systemctl list-timers --all >> "$REPORT_FILE" 2>&1
  section "ENABLED SERVICES"
  systemctl list-unit-files --state=enabled >> "$REPORT_FILE" 2>&1
fi

file /etc/rc.local
dir /etc/init.d

section "AUTHORIZED_KEYS"

count=0
while IFS=: read -r u _ uid _ _ home shell; do
  [[ -d "$home" ]] || continue
  [[ "$shell" =~ (nologin|false)$ ]] && continue
  for k in "$home/.ssh/authorized_keys"; do
    [[ -f "$k" ]] || continue
    record "USER=$u UID=$uid FILE=$k"
    head -n 50 "$k" >> "$REPORT_FILE"
  done
done < /etc/passwd

}

audit_logging_time(){

section "LOGGING"

[[ -f /etc/rsyslog.conf ]] && record "rsyslog.conf present"
[[ -f /etc/logrotate.conf ]] && record "logrotate.conf present"

file /etc/systemd/journald.conf

if has_cmd timedatectl; then
  section "TIME"
  timedatectl status >> "$REPORT_FILE"
fi

section "VAR LOG"
ls -lt /var/log | head -n 40 >> "$REPORT_FILE"

}

audit_persistence
audit_logging_time

echo "[*] Report written to $REPORT_FILE"
tail -n 40 "$REPORT_FILE"
