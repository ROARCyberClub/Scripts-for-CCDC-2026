#!/bin/bash
# ==============================================================================
# SCRIPT: firewall_safe.sh (Interactive Firewall with IPv6 & Auto-Rollback)
# PURPOSE: Configure iptables/ip6tables with whitelist rules and honeypot trap
# USAGE: Called by deploy.sh or run directly: sudo ./firewall_safe.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load dependencies
source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

require_root

# ------------------------------------------------------------------------------
# 1. BACKUP CURRENT RULES
# ------------------------------------------------------------------------------
subheader "Firewall Backup"

ROLLBACK_PATH=$(create_rollback_point "firewall")
if ! is_dry_run; then
    backup_iptables "$ROLLBACK_PATH"
fi

# ------------------------------------------------------------------------------
# 2. AUTO-ROLLBACK SAFETY (SSH Lockout Prevention)
# ------------------------------------------------------------------------------
ROLLBACK_PID=""

setup_auto_rollback() {
    if is_dry_run; then
        info "[DRY-RUN] Would set up auto-rollback timer"
        return
    fi
    
    local timeout="${FIREWALL_ROLLBACK_TIMEOUT:-60}"
    
    warn "Auto-rollback enabled: Rules will revert in ${timeout}s if not confirmed"
    
    # Background process to restore rules if not cancelled
    (
        sleep "$timeout"
        if [ -f "${ROLLBACK_PATH}/iptables.rules" ]; then
            iptables-restore < "${ROLLBACK_PATH}/iptables.rules" 2>/dev/null
            ip6tables-restore < "${ROLLBACK_PATH}/ip6tables.rules" 2>/dev/null
            echo "[AUTO-ROLLBACK] Firewall rules reverted due to timeout" | tee -a "$LOG_FILE"
        fi
    ) &
    ROLLBACK_PID=$!
}

cancel_auto_rollback() {
    if [ -n "$ROLLBACK_PID" ]; then
        kill "$ROLLBACK_PID" 2>/dev/null
        success "Auto-rollback cancelled. New rules are permanent."
    fi
}

# ------------------------------------------------------------------------------
# 3. HELPER FUNCTIONS
# ------------------------------------------------------------------------------

# Apply rule to both IPv4 and IPv6
apply_rule() {
    local rule="$1"
    run_cmd "iptables $rule"
    if [ "$USE_IPV6" == "true" ]; then
        # Convert icmp to icmpv6 for IPv6
        local rule6="${rule//icmp --icmp-type/icmpv6 --icmpv6-type}"
        run_cmd "ip6tables $rule6"
    fi
}

# Open port for specific protocol name
allow_protocol() {
    local ip="$1"
    local proto="$2"
    local ip_flag=""
    [ -n "$ip" ] && ip_flag="-s $ip"
    
    case "$proto" in
        "ssh")
            run_cmd "iptables -A INPUT $ip_flag -p tcp --dport $SSH_PORT -j ACCEPT"
            [ "$USE_IPV6" == "true" ] && run_cmd "ip6tables -A INPUT $ip_flag -p tcp --dport $SSH_PORT -j ACCEPT"
            ;;
        "http")
            apply_rule "-A INPUT $ip_flag -p tcp --dport 80 -j ACCEPT"
            ;;
        "https")
            apply_rule "-A INPUT $ip_flag -p tcp --dport 443 -j ACCEPT"
            ;;
        "dns")
            apply_rule "-A INPUT $ip_flag -p udp --dport 53 -j ACCEPT"
            apply_rule "-A INPUT $ip_flag -p tcp --dport 53 -j ACCEPT"
            ;;
        "mysql")
            apply_rule "-A INPUT $ip_flag -p tcp --dport 3306 -j ACCEPT"
            ;;
        "postgresql"|"pgsql")
            apply_rule "-A INPUT $ip_flag -p tcp --dport 5432 -j ACCEPT"
            ;;
        "ftp")
            apply_rule "-A INPUT $ip_flag -p tcp --dport 21 -j ACCEPT"
            ;;
        "smtp")
            apply_rule "-A INPUT $ip_flag -p tcp --dport 25 -j ACCEPT"
            ;;
        "pop3")
            apply_rule "-A INPUT $ip_flag -p tcp --dport 110 -j ACCEPT"
            ;;
        "imap")
            apply_rule "-A INPUT $ip_flag -p tcp --dport 143 -j ACCEPT"
            ;;
        "smb"|"samba")
            apply_rule "-A INPUT $ip_flag -p tcp --dport 139 -j ACCEPT"
            apply_rule "-A INPUT $ip_flag -p tcp --dport 445 -j ACCEPT"
            ;;
        "icmp")
            run_cmd "iptables -A INPUT $ip_flag -p icmp --icmp-type echo-request -j ACCEPT"
            [ "$USE_IPV6" == "true" ] && run_cmd "ip6tables -A INPUT $ip_flag -p icmpv6 --icmpv6-type echo-request -j ACCEPT"
            ;;
        *)
            warn "Unknown protocol: $proto"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 4. PREVIEW RULES (Interactive Mode)
# ------------------------------------------------------------------------------
if [ "$INTERACTIVE" == "true" ]; then
    subheader "Firewall Rules Preview"
    
    echo -e "${BOLD}The following rules will be applied:${NC}"
    echo ""
    echo "  ${CYAN}Default Policies:${NC}"
    echo "    • INPUT: DROP (block all by default)"
    echo "    • OUTPUT: ACCEPT (allow all outgoing)"
    if [ "$USE_DOCKER" != "true" ]; then
        echo "    • FORWARD: DROP"
    else
        echo "    • FORWARD: (unchanged - Docker mode)"
    fi
    echo ""
    echo "  ${CYAN}Allowed Traffic:${NC}"
    echo "    • Loopback interface (localhost)"
    echo "    • Established/Related connections"
    echo "    • SSH on port $SSH_PORT"
    for proto in "${ALLOWED_PROTOCOLS[@]}"; do
        echo "    • Protocol: $proto"
    done
    echo ""
    echo "  ${CYAN}Scoreboard Whitelist:${NC}"
    for ip in "${SCOREBOARD_IPS[@]}"; do
        echo "    • $ip -> Full access to allowed protocols"
    done
    echo ""
    echo "  ${CYAN}Honeypot Trap:${NC}"
    echo "    • Port $TRAP_PORT -> Ban for ${BAN_TIME}s on access"
    echo ""
    
    if ! confirm "Apply these firewall rules?" "y"; then
        info "Firewall setup cancelled."
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# 5. SET UP AUTO-ROLLBACK
# ------------------------------------------------------------------------------
if [ "$INTERACTIVE" == "true" ] && ! is_dry_run; then
    setup_auto_rollback
fi

# ------------------------------------------------------------------------------
# 6. FLUSH EXISTING RULES
# ------------------------------------------------------------------------------
subheader "Applying Firewall Rules"

info "Flushing existing rules..."

if [ "$USE_DOCKER" == "true" ]; then
    warn "Docker mode: Flushing INPUT chain only"
    run_cmd "iptables -F INPUT"
    [ "$USE_IPV6" == "true" ] && run_cmd "ip6tables -F INPUT"
else
    run_cmd "iptables -F"
    run_cmd "iptables -X"
    if [ "$USE_IPV6" == "true" ]; then
        run_cmd "ip6tables -F"
        run_cmd "ip6tables -X"
    fi
fi

# ------------------------------------------------------------------------------
# 7. SET DEFAULT POLICIES
# ------------------------------------------------------------------------------
info "Setting default policies..."

run_cmd "iptables -P INPUT DROP"
run_cmd "iptables -P OUTPUT ACCEPT"
if [ "$USE_DOCKER" != "true" ]; then
    run_cmd "iptables -P FORWARD DROP"
fi

if [ "$USE_IPV6" == "true" ]; then
    run_cmd "ip6tables -P INPUT DROP"
    run_cmd "ip6tables -P OUTPUT ACCEPT"
    if [ "$USE_DOCKER" != "true" ]; then
        run_cmd "ip6tables -P FORWARD DROP"
    fi
fi

# ------------------------------------------------------------------------------
# 8. TRUSTED ZONES
# ------------------------------------------------------------------------------
info "Allowing trusted traffic..."

# Loopback
apply_rule "-A INPUT -i lo -j ACCEPT"

# Established connections
run_cmd "iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
[ "$USE_IPV6" == "true" ] && run_cmd "ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"

# ------------------------------------------------------------------------------
# 9. SCOREBOARD WHITELIST
# ------------------------------------------------------------------------------
info "Whitelisting scoreboard IPs..."

for ip in "${SCOREBOARD_IPS[@]}"; do
    success "Whitelisting: $ip"
    
    # SSH always allowed for scoreboard
    run_cmd "iptables -A INPUT -s $ip -p tcp --dport $SSH_PORT -j ACCEPT"
    
    # Other protocols
    for proto in "${ALLOWED_PROTOCOLS[@]}"; do
        allow_protocol "$ip" "$proto"
    done
done

# ------------------------------------------------------------------------------
# 10. ANTI-SCANNER TRAP CHECK
# ------------------------------------------------------------------------------
if [ -n "$TRAP_PORT" ]; then
    info "Setting up anti-scanner trap..."
    
    # Load required kernel module
    if ! is_dry_run; then
        modprobe xt_recent 2>/dev/null || true
    fi
    
    # Check trap list and drop banned IPs
    run_cmd "iptables -A INPUT -m recent --name PORT_SCANNER --update --seconds $BAN_TIME -j DROP"
    [ "$USE_IPV6" == "true" ] && run_cmd "ip6tables -A INPUT -m recent --name PORT_SCANNER --update --seconds $BAN_TIME -j DROP"
fi

# ------------------------------------------------------------------------------
# 11. PUBLIC SERVICES (General Access)
# ------------------------------------------------------------------------------
info "Allowing public services..."

# SSH (always)
success "SSH allowed on port: $SSH_PORT"
apply_rule "-A INPUT -p tcp --dport $SSH_PORT -j ACCEPT"

# Other protocols for all sources
for proto in "${ALLOWED_PROTOCOLS[@]}"; do
    if [ "$proto" != "ssh" ]; then
        allow_protocol "" "$proto"
    fi
done

# ------------------------------------------------------------------------------
# 12. HONEYPOT TRAP
# ------------------------------------------------------------------------------
if [ -n "$TRAP_PORT" ]; then
    info "Setting up honeypot on port: $TRAP_PORT"
    
    # Log and add to ban list
    run_cmd "iptables -A INPUT -p tcp --dport $TRAP_PORT -m recent --name PORT_SCANNER --set -j LOG --log-prefix 'TRAP_TRIGGERED: ' --log-level 4"
    run_cmd "iptables -A INPUT -p tcp --dport $TRAP_PORT -j DROP"
    
    if [ "$USE_IPV6" == "true" ]; then
        run_cmd "ip6tables -A INPUT -p tcp --dport $TRAP_PORT -m recent --name PORT_SCANNER --set -j LOG --log-prefix 'TRAP_TRIGGERED: ' --log-level 4"
        run_cmd "ip6tables -A INPUT -p tcp --dport $TRAP_PORT -j DROP"
    fi
fi

# ------------------------------------------------------------------------------
# 13. CONFIRMATION & ROLLBACK DECISION
# ------------------------------------------------------------------------------
if [ "$INTERACTIVE" == "true" ] && ! is_dry_run; then
    echo ""
    warn "Firewall rules have been applied!"
    warn "You have ${FIREWALL_ROLLBACK_TIMEOUT:-60} seconds to confirm."
    echo ""
    
    # Quick connectivity test suggestion
    info "Test your connection NOW from another terminal:"
    echo -e "    ${CYAN}ssh $(whoami)@$(hostname -I 2>/dev/null | awk '{print $1}') -p $SSH_PORT${NC}"
    echo ""
    
    if confirm "Can you still connect? Keep new firewall rules?" "n"; then
        cancel_auto_rollback
    else
        warn "Rules will be automatically reverted..."
        exit 1
    fi
else
    # Non-interactive or dry-run: no auto-rollback needed
    if ! is_dry_run; then
        cancel_auto_rollback 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# 14. SUMMARY
# ------------------------------------------------------------------------------
subheader "Firewall Summary"

success "Firewall configured successfully!"
info "Docker Mode: $USE_DOCKER"
info "IPv6 Enabled: $USE_IPV6"
info "Trap Port: $TRAP_PORT (ban time: ${BAN_TIME}s)"

if ! is_dry_run; then
    log_action "Firewall rules applied successfully"
fi