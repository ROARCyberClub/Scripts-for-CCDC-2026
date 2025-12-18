#!/bin/bash
# ==============================================================================
# SCRIPT: service_killer.sh (Smart Logic)
# PURPOSE: Automatically kills services NOT listed in vars.sh (SCORED_SERVICES)
# ==============================================================================

# 1. Import Configuration
if [ -f "./vars.sh" ]; then
    source ./vars.sh
else
    echo "[ERROR] vars.sh not found! I don't know what to protect."
    exit 1
fi

# 2. Root Check
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Please run as ROOT (sudo)." 
   exit 1
fi

# ------------------------------------------------------------------------------
# 3. THE BLACKLIST (Potential Risky Services)
# ------------------------------------------------------------------------------
# The script attempts to disable these services.
# CRITICAL: If a service is listed in 'SCORED_SERVICES' (inside vars.sh),
# it will be SKIPPED automatically (Protected).
TARGET_SERVICES=(
    # [Remote Access - KILL THESE FIRST]
    "telnet" "telnetd" "rsh" "rlogin" "vnc" "vncserver" "xrdp" "teamviewer" 
    
    # [Web Servers]
    "apache2" "httpd" "nginx" "tomcat" "tomcat9" "jboss"
    
    # [Databases]
    "mysql" "mysqld" "mariadb" "postgresql" "psql" "mongodb" "mongod" "redis-server"
    
    # [File Sharing]
    "vsftpd" "proftpd" "pure-ftpd" "smbd" "nmbd" "nfs-kernel-server" "rpcbind"
    
    # [Mail]
    "postfix" "exim4" "sendmail" "dovecot"
    
    # [Network & Bloat]
    "avahi-daemon" "cups" "cups-browsed" "bluetooth" "bluez"
)

# ------------------------------------------------------------------------------
# 4. Helper Functions
# ------------------------------------------------------------------------------
INIT_SYSTEM="UNKNOWN"
if command -v systemctl >/dev/null 2>&1; then INIT_SYSTEM="SYSTEMD";
elif command -v rc-service >/dev/null 2>&1; then INIT_SYSTEM="OPENRC";
else INIT_SYSTEM="SYSVINIT"; fi

# Check if a service is in the PROTECTED_SERVICES whitelist
is_protected() {
    local svc_name=$1
    for protected in "${PROTECTED_SERVICES[@]}"; do
        if [[ "$protected" == "$svc_name" ]]; then
            return 0 # True (Protected)
        fi
    done
    return 1 # False
}

disable_service() {
    local svc="$1"
    
    if is_protected "$svc"; then
        echo -e "\e[32m[SAFE] Skipping Protected Service: $svc\e[0m"
        return
    fi

    case "$INIT_SYSTEM" in
        "SYSTEMD")
            if systemctl is-active --quiet "$svc" || systemctl is-enabled --quiet "$svc"; then
                echo -e "\e[31m[KILL] Disabling Unscored Service: $svc\e[0m"
                systemctl stop "$svc" 2>/dev/null
                systemctl disable "$svc" 2>/dev/null
                systemctl mask "$svc" 2>/dev/null
            fi
            ;;
        "SYSVINIT"|"OPENRC")
            if [ -f "/etc/init.d/$svc" ]; then
                echo -e "\e[31m[KILL] Disabling Unscored Service: $svc\e[0m"
                service "$svc" stop 2>/dev/null
            fi
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 5. Execution Loop
# ------------------------------------------------------------------------------
echo "--------------------------------------------------------"
echo " SMART SERVICE KILLER (Mode: $INIT_SYSTEM)"
echo " Protected Services: ${PROTECTED_SERVICES[*]}"
echo "--------------------------------------------------------"

for target in "${TARGET_SERVICES[@]}"; do
    disable_service "$target"
done

echo "--------------------------------------------------------"
echo " [DONE] Check 'netstat -tulnp' to verify open ports."
echo "--------------------------------------------------------"