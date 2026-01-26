#!/bin/bash
# ==============================================================================
# SCRIPT: firewall_safe.sh (ufw for Ubuntu 24)
# PURPOSE: Configure ufw with minimal rules for workstation
# USAGE: Called by deploy.sh or run directly: sudo ./firewall_safe.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

require_root

# ------------------------------------------------------------------------------
# 1. CHECK UFW
# ------------------------------------------------------------------------------
subheader "Firewall Check"

if ! command_exists ufw; then
    error "ufw not found. Install ufw first."
    error "Run: apt install ufw -y"
    exit 1
fi

success "ufw is available"

# ------------------------------------------------------------------------------
# 2. BACKUP CURRENT RULES
# ------------------------------------------------------------------------------
subheader "Firewall Backup"

ROLLBACK_PATH=$(create_rollback_point "firewall")
if ! is_dry_run; then
    backup_ufw "$ROLLBACK_PATH"
fi

# ------------------------------------------------------------------------------
# 3. AUTO-ROLLBACK SAFETY
# ------------------------------------------------------------------------------
ROLLBACK_PID=""

setup_auto_rollback() {
    if is_dry_run; then
        info "[DRY-RUN] Would set up auto-rollback timer"
        return
    fi
    
    local timeout="${FIREWALL_ROLLBACK_TIMEOUT:-60}"
    warn "Auto-rollback enabled: Rules will revert in ${timeout}s if not confirmed"
    
    (
        sleep "$timeout"
        if [ -d "$ROLLBACK_PATH" ]; then
            restore_ufw "$ROLLBACK_PATH"
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
# 4. PREVIEW RULES
# ------------------------------------------------------------------------------
if [ "$INTERACTIVE" == "true" ]; then
    subheader "Firewall Rules Preview"
    
    echo -e "${BOLD}The following rules will be applied:${NC}"
    echo ""
    echo "  ${CYAN}Default Policy:${NC}"
    echo "    - Incoming: DENY"
    echo "    - Outgoing: ALLOW"
    echo ""
    echo "  ${CYAN}Allowed Ports:${NC}"
    echo "    - SSH: port $SSH_PORT (minimal workstation config)"
    echo ""
    echo "  ${CYAN}Honeypot Trap:${NC}"
    echo "    - Port $TRAP_PORT -> Logged and dropped"
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
# 6. RESET UFW
# ------------------------------------------------------------------------------
subheader "Applying Firewall Rules"

info "Resetting ufw to defaults..."
if ! is_dry_run; then
    echo "y" | ufw reset >/dev/null 2>&1
fi

# Set default policies
info "Setting default policies..."
run_ufw_cmd "default deny incoming"
run_ufw_cmd "default allow outgoing"

# ------------------------------------------------------------------------------
# 7. ADD SSH (ONLY PORT FOR WORKSTATION)
# ------------------------------------------------------------------------------
info "Allowing SSH on port $SSH_PORT..."
run_ufw_cmd "allow $SSH_PORT/tcp comment 'SSH'"
success "SSH allowed on port: $SSH_PORT"

# ------------------------------------------------------------------------------
# 8. SCOREBOARD IPS
# ------------------------------------------------------------------------------
if [ ${#SCOREBOARD_IPS[@]} -gt 0 ]; then
    subheader "Scoreboard Whitelist"
    
    for ip in "${SCOREBOARD_IPS[@]}"; do
        info "Whitelisting scoreboard IP: $ip"
        run_ufw_cmd "allow from $ip comment 'Scoreboard'"
    done
fi

# ------------------------------------------------------------------------------
# 9. ENABLE UFW
# ------------------------------------------------------------------------------
subheader "Enabling Firewall"

info "Enabling ufw..."
if ! is_dry_run; then
    echo "y" | ufw enable >/dev/null 2>&1
fi

success "Firewall enabled!"

if ! is_dry_run; then
    echo ""
    info "Current firewall status:"
    ufw status numbered
fi

# ------------------------------------------------------------------------------
# 10. CONFIRMATION
# ------------------------------------------------------------------------------
if [ "$INTERACTIVE" == "true" ] && ! is_dry_run; then
    echo ""
    warn "Firewall rules have been applied!"
    warn "You have ${FIREWALL_ROLLBACK_TIMEOUT:-60} seconds to confirm."
    echo ""
    
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
    if ! is_dry_run; then
        cancel_auto_rollback 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# 11. SUMMARY
# ------------------------------------------------------------------------------
subheader "Firewall Summary"

success "Firewall configured successfully!"
info "Firewall Type: ufw"
info "Default Policy: deny incoming, allow outgoing"
info "SSH Port: $SSH_PORT"
info "Note: Workstation - minimal ports only"

if ! is_dry_run; then
    log_action "Firewall rules applied successfully (ufw)"
fi