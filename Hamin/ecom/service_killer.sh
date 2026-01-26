#!/bin/bash
# ==============================================================================
# SCRIPT: service_killer.sh (Interactive Service Management)
# PURPOSE: Disable potentially risky services not in the protected whitelist
# USAGE: Called by deploy.sh or run directly: sudo ./service_killer.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load dependencies
source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

require_root

# ------------------------------------------------------------------------------
# 1. DETECT INIT SYSTEM
# ------------------------------------------------------------------------------
INIT_SYSTEM="UNKNOWN"
if command_exists systemctl; then
    INIT_SYSTEM="SYSTEMD"
elif command_exists rc-service; then
    INIT_SYSTEM="OPENRC"
elif [ -d /etc/init.d ]; then
    INIT_SYSTEM="SYSVINIT"
fi

info "Init system detected: $INIT_SYSTEM"

# ------------------------------------------------------------------------------
# 2. TARGET SERVICES (Potential Risks)
# ------------------------------------------------------------------------------
# These will be disabled UNLESS they are in PROTECTED_SERVICES

TARGET_SERVICES=(
    # Remote Access (HIGHEST PRIORITY - Kill First!)
    "telnet" "telnetd" "rsh" "rlogin" "rexec"
    "vnc" "vncserver" "tigervnc" "tightvncserver"
    "xrdp" "teamviewer"
    
    # Web Servers
    "apache2" "httpd" "nginx" "lighttpd"
    "tomcat" "tomcat9" "jboss"
    
    # Databases
    "mysql" "mysqld" "mariadb"
    "postgresql" "postgresql-14" "postgresql-15"
    "mongodb" "mongod"
    "redis" "redis-server"
    
    # File Sharing
    "vsftpd" "proftpd" "pure-ftpd"
    "smbd" "nmbd" "samba"
    "nfs-server" "nfs-kernel-server" "rpcbind"
    
    # Mail
    "postfix" "exim4" "sendmail" "dovecot"
    
    # Conflicting Firewalls (We use iptables directly)
    "ufw" "firewalld"
    
    # Network & Bloat
    "avahi-daemon" "avahi" "mdns"
    "cups" "cups-browsed"
    "bluetooth" "bluez"
    "snapd"
)

# ------------------------------------------------------------------------------
# 3. HELPER FUNCTIONS
# ------------------------------------------------------------------------------

# Check if service is in protected list
is_protected_service() {
    local svc="$1"
    for protected in "${PROTECTED_SERVICES[@]}"; do
        if [[ "$protected" == "$svc" ]]; then
            return 0
        fi
    done
    return 1
}

# Check if service exists and is active
check_service_status() {
    local svc="$1"
    
    case "$INIT_SYSTEM" in
        "SYSTEMD")
            if systemctl list-unit-files "${svc}.service" &>/dev/null; then
                if systemctl is-active --quiet "$svc" 2>/dev/null; then
                    echo "RUNNING"
                elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
                    echo "ENABLED"
                else
                    echo "STOPPED"
                fi
            else
                echo "NOT_FOUND"
            fi
            ;;
        "SYSVINIT"|"OPENRC")
            if [ -f "/etc/init.d/$svc" ]; then
                if service "$svc" status &>/dev/null; then
                    echo "RUNNING"
                else
                    echo "STOPPED"
                fi
            else
                echo "NOT_FOUND"
            fi
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

# Disable a service
disable_service() {
    local svc="$1"
    
    case "$INIT_SYSTEM" in
        "SYSTEMD")
            run_cmd "systemctl stop $svc 2>/dev/null"
            run_cmd "systemctl disable $svc 2>/dev/null"
            run_cmd "systemctl mask $svc 2>/dev/null"
            ;;
        "SYSVINIT")
            run_cmd "service $svc stop 2>/dev/null"
            if command_exists update-rc.d; then
                run_cmd "update-rc.d -f $svc disable 2>/dev/null"
            fi
            ;;
        "OPENRC")
            run_cmd "rc-service $svc stop 2>/dev/null"
            run_cmd "rc-update del $svc 2>/dev/null"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 4. SCAN & CATEGORIZE SERVICES
# ------------------------------------------------------------------------------
subheader "Service Scan"

PROTECTED_FOUND=()
RISKY_FOUND=()
TO_DISABLE=()

for svc in "${TARGET_SERVICES[@]}"; do
    status=$(check_service_status "$svc")
    
    if [[ "$status" == "NOT_FOUND" ]] || [[ "$status" == "UNKNOWN" ]]; then
        continue
    fi
    
    if is_protected_service "$svc"; then
        PROTECTED_FOUND+=("$svc ($status)")
    else
        if [[ "$status" == "RUNNING" ]] || [[ "$status" == "ENABLED" ]]; then
            RISKY_FOUND+=("$svc")
            TO_DISABLE+=("$svc")
        fi
    fi
done

# Display findings
if [ ${#PROTECTED_FOUND[@]} -gt 0 ]; then
    info "Protected services (will NOT be stopped):"
    for svc in "${PROTECTED_FOUND[@]}"; do
        echo -e "    ${GREEN}✓${NC} $svc"
    done
fi

echo ""

if [ ${#RISKY_FOUND[@]} -gt 0 ]; then
    warn "Risky services found (will be disabled):"
    for svc in "${RISKY_FOUND[@]}"; do
        status=$(check_service_status "$svc")
        echo -e "    ${RED}✗${NC} $svc [$status]"
    done
else
    success "No risky services found!"
    exit 0
fi

# ------------------------------------------------------------------------------
# 5. INTERACTIVE SERVICE SELECTION
# ------------------------------------------------------------------------------
echo ""

if [ "$INTERACTIVE" == "true" ]; then
    info "You can review each service before disabling."
    echo ""
    
    if confirm "Disable all risky services at once?" "n"; then
        # Batch mode within interactive
        BATCH_MODE="true"
    else
        BATCH_MODE="false"
    fi
else
    BATCH_MODE="true"
fi

# ------------------------------------------------------------------------------
# 6. DISABLE SERVICES
# ------------------------------------------------------------------------------
subheader "Disabling Services"

DISABLED_COUNT=0
SKIPPED_COUNT=0

for svc in "${TO_DISABLE[@]}"; do
    status=$(check_service_status "$svc")
    
    if [[ "$BATCH_MODE" != "true" ]] && [ "$INTERACTIVE" == "true" ]; then
        echo ""
        echo -e "${YELLOW}Service:${NC} $svc"
        echo -e "  Status: $status"
        
        # Try to get description
        if [ "$INIT_SYSTEM" == "SYSTEMD" ]; then
            desc=$(systemctl show -p Description "$svc" 2>/dev/null | cut -d= -f2)
            [ -n "$desc" ] && echo -e "  Description: $desc"
        fi
        
        if ! confirm "Disable this service?" "y"; then
            warn "Skipping: $svc"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        fi
    fi
    
    if is_dry_run; then
        info "[DRY-RUN] Would disable: $svc"
    else
        disable_service "$svc"
        action "Disabled: $svc"
        log_action "Disabled service: $svc"
    fi
    
    DISABLED_COUNT=$((DISABLED_COUNT + 1))
done

# ------------------------------------------------------------------------------
# 7. SUMMARY
# ------------------------------------------------------------------------------
subheader "Service Cleanup Summary"

echo ""
success "Service cleanup completed!"
info "Disabled: $DISABLED_COUNT services"
info "Skipped: $SKIPPED_COUNT services"
info "Protected: ${#PROTECTED_FOUND[@]} services"

if ! is_dry_run; then
    echo ""
    info "Verify with: netstat -tulnp | grep LISTEN"
fi