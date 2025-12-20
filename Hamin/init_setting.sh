#!/bin/bash
# ==============================================================================
# SCRIPT: init_setting.sh (Multi-OS Support)
# ==============================================================================

if [[ $EUID -ne 0 ]]; then echo "[ERROR] Run as ROOT."; exit 1; fi

# 1. Password Setup
NEW_PASS="CCDC_P@ssw0rd_2025!" 
if [ -z "$NEW_PASS" ]; then echo "[ERROR] Set NEW_PASS!"; exit 1; fi

# 2. Smart Backup (Check ALL possible paths)
BACKUP_DIR="/root/ccdc_backup_$(date +%H%M)"
mkdir -p "$BACKUP_DIR"
echo "[*] Backing up configs to $BACKUP_DIR..."

# List of critical paths for BOTH Debian and RHEL systems
CRITICAL_PATHS=(
    "/etc/ssh"
    "/etc/passwd" 
    "/etc/shadow" 
    "/etc/group"
    "/etc/apache2"   # Debian/Ubuntu Web
    "/etc/httpd"     # RHEL/CentOS Web
    "/etc/nginx"     # Nginx
    "/etc/mysql"     # Debian SQL
    "/var/lib/mysql" # SQL Data (Optional, might be large)
    "/etc/my.cnf.d"  # RHEL SQL Config
)

for path in "${CRITICAL_PATHS[@]}"; do
    if [ -e "$path" ]; then
        cp -r "$path" "$BACKUP_DIR/" 2>/dev/null
        # echo "    -> Backed up: $path"
    fi
done

# 3. Password Change & Kick
echo "[!] CHANGING PASSWORDS AND KICKING USERS..."
awk -F: '($3 >= 1000 || $1 == "root") {print $1}' /etc/passwd | while read user; do
    shell=$(grep "^$user:" /etc/passwd | awk -F: '{print $7}')
    if [[ "$shell" == *"/nologin"* ]] || [[ "$shell" == *"/false"* ]]; then continue; fi

    echo "$user:$NEW_PASS" | chpasswd
    if [ $? -eq 0 ]; then
        echo "   [+] Secured: $user"
        if [ "$user" != "root" ]; then
             pkill -KILL -u "$user"
        fi
    fi
done

# 4. Nuke Keys
find /home -name "authorized_keys" -delete
find /root -name "authorized_keys" -delete

echo "[OK] Initial hardening done."