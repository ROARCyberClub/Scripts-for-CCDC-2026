#!/bin/bash
# ==============================================================================
# SCRIPT: firewall_safe.sh (firewalld for Fedora 42)
# PURPOSE: Configure firewalld with mail server ports and security rules
# USAGE: Called by deploy.sh or run directly: sudo ./firewall_safe.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load dependencies
source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

require_root

# ------------------------------------------------------------------------------
# 1. CHECK FIREWALLD
# ------------------------------------------------------------------------------
subheader "Firewall Check"

if ! command_exists firewall-cmd; then
    error "firewall-cmd not found. Install firewalld first."
    error "Run: dnf install firewalld -y && systemctl enable --now firewalld"
    exit 1
fi

if ! systemctl is-active --quiet firewalld; then
    info "Starting firewalld service..."
    if ! is_dry_run; then
        systemctl start firewalld
        systemctl enable firewalld
    fi
fi

success "firewalld is active"

# ------------------------------------------------------------------------------
# 2. BACKUP CURRENT RULES
# ------------------------------------------------------------------------------
subheader "Firewall Backup"

ROLLBACK_PATH=$(create_rollback_point "firewall")
if ! is_dry_run; then
    backup_firewalld "$ROLLBACK_PATH"
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
            restore_firewalld "$ROLLBACK_PATH"
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
    echo "  ${CYAN}Default Zone: public${NC}"
    echo ""
    echo "  ${CYAN}Standard Ports:${NC}"
    echo "    - SSH: port $SSH_PORT"
    echo "    - HTTP: port 80"
    echo "    - HTTPS: port 443"
    echo ""
    echo "  ${CYAN}Mail Ports:${NC}"
    echo "    - SMTP: port ${MAIL_SMTP_PORT:-25}"
    echo "    - IMAP: port ${MAIL_IMAP_PORT:-143}"
    echo "    - POP3: port ${MAIL_POP3_PORT:-110}"
    echo ""
    echo "  ${CYAN}Honeypot Trap:${NC}"
    echo "    - Port $TRAP_PORT -> Log and drop"
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
# 6. RESET FIREWALL
# ------------------------------------------------------------------------------
subheader "Applying Firewall Rules"

info "Setting default zone to public..."
run_firewall_cmd "--set-default-zone=public"

info "Removing existing port rules..."
if ! is_dry_run; then
    for port in $(firewall-cmd --list-ports --permanent 2>/dev/null); do
        run_firewall_cmd "--permanent --remove-port=$port"
    done
fi

# ------------------------------------------------------------------------------
# 7. ADD SSH
# ------------------------------------------------------------------------------
info "Allowing SSH on port $SSH_PORT..."
if [ "$SSH_PORT" == "22" ]; then
    run_firewall_cmd "--permanent --add-service=ssh"
else
    run_firewall_cmd "--permanent --add-port=${SSH_PORT}/tcp"
fi
success "SSH allowed on port: $SSH_PORT"

# ------------------------------------------------------------------------------
# 8. ADD STANDARD PROTOCOLS
# ------------------------------------------------------------------------------
info "Allowing standard protocols..."

for proto in "${ALLOWED_PROTOCOLS[@]}"; do
    case "$proto" in
        "ssh") ;;
        "http")
            run_firewall_cmd "--permanent --add-service=http"
            success "HTTP (80) allowed"
            ;;
        "https")
            run_firewall_cmd "--permanent --add-service=https"
            success "HTTPS (443) allowed"
            ;;
        "icmp")
            success "ICMP (ping) allowed"
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 9. ADD MAIL PORTS
# ------------------------------------------------------------------------------
subheader "Mail Server Ports"

info "Allowing mail ports..."

# SMTP
run_firewall_cmd "--permanent --add-port=${MAIL_SMTP_PORT:-25}/tcp"
success "SMTP: ${MAIL_SMTP_PORT:-25}"

# IMAP
run_firewall_cmd "--permanent --add-port=${MAIL_IMAP_PORT:-143}/tcp"
success "IMAP: ${MAIL_IMAP_PORT:-143}"

# POP3
run_firewall_cmd "--permanent --add-port=${MAIL_POP3_PORT:-110}/tcp"
success "POP3: ${MAIL_POP3_PORT:-110}"

# Secure ports (optional - uncomment if needed)
# run_firewall_cmd "--permanent --add-port=${MAIL_SMTPS_PORT:-465}/tcp"
# run_firewall_cmd "--permanent --add-port=${MAIL_SUBMISSION_PORT:-587}/tcp"
# run_firewall_cmd "--permanent --add-port=${MAIL_IMAPS_PORT:-993}/tcp"
# run_firewall_cmd "--permanent --add-port=${MAIL_POP3S_PORT:-995}/tcp"

# ------------------------------------------------------------------------------
# 10. HONEYPOT TRAP
# ------------------------------------------------------------------------------
if [ -n "$TRAP_PORT" ]; then
    subheader "Honeypot Trap"
    
    info "Setting up trap on port $TRAP_PORT..."
    
    TRAP_RULE="rule family=\"ipv4\" port port=\"${TRAP_PORT}\" protocol=\"tcp\" log prefix=\"TRAP_TRIGGERED: \" level=\"warning\" drop"
    run_firewall_cmd "--permanent --add-rich-rule='$TRAP_RULE'"
    
    if [ "$USE_IPV6" == "true" ]; then
        TRAP_RULE6="rule family=\"ipv6\" port port=\"${TRAP_PORT}\" protocol=\"tcp\" log prefix=\"TRAP_TRIGGERED: \" level=\"warning\" drop"
        run_firewall_cmd "--permanent --add-rich-rule='$TRAP_RULE6'"
    fi
    
    success "Honeypot trap set on port: $TRAP_PORT"
fi

# ------------------------------------------------------------------------------
# 11. RELOAD FIREWALL
# ------------------------------------------------------------------------------
subheader "Applying Changes"

info "Reloading firewalld..."
run_firewall_cmd "--reload"

success "Firewall rules applied!"

if ! is_dry_run; then
    echo ""
    info "Current firewall configuration:"
    firewall-cmd --list-all
fi

# ------------------------------------------------------------------------------
# 12. CONFIRMATION
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
# 13. SUMMARY
# ------------------------------------------------------------------------------
subheader "Firewall Summary"

success "Firewall configured successfully!"
info "Firewall Type: firewalld"
info "Default Zone: public"
info "SSH Port: $SSH_PORT"
info "Mail Ports: SMTP(${MAIL_SMTP_PORT:-25}), IMAP(${MAIL_IMAP_PORT:-143}), POP3(${MAIL_POP3_PORT:-110})"
info "Trap Port: ${TRAP_PORT:-none}"

if ! is_dry_run; then
    log_action "Firewall rules applied successfully (firewalld)"
fi