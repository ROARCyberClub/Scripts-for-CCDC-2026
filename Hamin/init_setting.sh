#!/bin/bash
# ==============================================================================
# SCRIPT: init_setting.sh (Safe Mode: Don't Kill Admin)
# ==============================================================================

if [[ $EUID -ne 0 ]]; then echo "[ERROR] Run as ROOT."; exit 1; fi

# 1. Password Setup
NEW_PASS="P@ssw0rd" 
if [ -z "$NEW_PASS" ]; then echo "[ERROR] Set NEW_PASS!"; exit 1; fi

# [CRITICAL FIX] Identify the Admin User to prevent self-lockout
ADMIN_USER=${SUDO_USER:-$(who am i | awk '{print $1}')}
if [ -z "$ADMIN_USER" ]; then ADMIN_USER="root"; fi
echo "[*] Detected Admin User: $ADMIN_USER (Will NOT be kicked)"

# 2. Smart Backup
BACKUP_DIR="/root/ccdc_backup_$(date +%H%M)"
mkdir -p "$BACKUP_DIR"
echo "[*] Backing up configs to $BACKUP_DIR..."

CRITICAL_PATHS=(
    "/etc/ssh" "/etc/passwd" "/etc/shadow" "/etc/group"
    "/etc/apache2" "/etc/httpd" "/etc/nginx" 
    "/etc/mysql" "/var/lib/mysql" "/etc/my.cnf.d"
)

for path in "${CRITICAL_PATHS[@]}"; do
    if [ -e "$path" ]; then cp -r "$path" "$BACKUP_DIR/" 2>/dev/null; fi
done

# 3. Password Change & Kick (Safely)
echo "[!] CHANGING PASSWORDS AND KICKING USERS..."

awk -F: '($3 >= 1000 || $1 == "root") {print $1}' /etc/passwd | while read user; do
    # Skip nologin users
    shell=$(grep "^$user:" /etc/passwd | awk -F: '{print $7}')
    if [[ "$shell" == *"/nologin"* ]] || [[ "$shell" == *"/false"* ]]; then continue; fi

    # Change Password
    echo "$user:$NEW_PASS" | chpasswd
    
    # [LOGIC FIX] KICK USER (Exceptions: root AND current admin)
    if [ $? -eq 0 ]; then
        if [ "$user" != "root" ] && [ "$user" != "$ADMIN_USER" ]; then
             echo -e "   \e[31m[KILL] Kicking suspicious user: $user\e[0m"
             pkill -KILL -u "$user"
        else
             echo -e "   \e[32m[SAFE] Changing password but keeping session: $user\e[0m"
        fi
    fi
done

# 4. Nuke Keys
find /home -name "authorized_keys" -delete
find /root -name "authorized_keys" -delete

echo "[OK] Initial hardening done."