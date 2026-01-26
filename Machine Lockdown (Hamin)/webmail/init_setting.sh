#!/bin/bash
# ==============================================================================
# SCRIPT: init_setting.sh (Interactive Initial Hardening)
# PURPOSE: Secure the system by changing passwords, kicking users, removing keys
# USAGE: Called by deploy.sh or run directly: sudo ./init_setting.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load dependencies
source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

require_root

# ------------------------------------------------------------------------------
# 1. IDENTIFY CURRENT ADMIN (Prevent self-lockout)
# ------------------------------------------------------------------------------
CURRENT_ADMIN=$(get_current_admin)
info "Current admin user detected: $CURRENT_ADMIN (will NOT be kicked)"

# Add current admin to protected users
PROTECTED_USERS+=("$CURRENT_ADMIN")

# ------------------------------------------------------------------------------
# 2. PASSWORD SETUP
# ------------------------------------------------------------------------------
subheader "Password Configuration"

if [ "$INTERACTIVE" == "true" ]; then
    info "You will set a new password for ALL system users."
    warn "Make sure to remember this password!"
    echo ""
    NEW_PASS=$(prompt_password "Enter new password for all users")
else
    # Non-interactive: require password from environment variable
    if [ -z "$CCDC_PASSWORD" ]; then
        error "Non-interactive mode requires CCDC_PASSWORD environment variable."
        error "Usage: CCDC_PASSWORD='yourpass' ./init_setting.sh"
        exit 1
    fi
    NEW_PASS="$CCDC_PASSWORD"
    info "Using password from CCDC_PASSWORD environment variable."
fi

# ------------------------------------------------------------------------------
# 3. BACKUP CRITICAL CONFIGURATIONS
# ------------------------------------------------------------------------------
subheader "Backup Configuration Files"

BACKUP_DIR="/root/ccdc_backup_$(date +%Y%m%d_%H%M%S)"

if ! is_dry_run; then
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
fi

CRITICAL_PATHS=(
    "/etc/ssh"
    "/etc/passwd"
    "/etc/shadow"
    "/etc/group"
    "/etc/sudoers"
    "/etc/sudoers.d"
    # Mail server configuration (CRITICAL!)
    "/etc/postfix"
    "/etc/dovecot"
    "/etc/aliases"
    # Web interface
    "/etc/httpd"
    "/etc/nginx"
    "/etc/php-fpm.d"
)

info "Backing up configurations to: $BACKUP_DIR"

for path in "${CRITICAL_PATHS[@]}"; do
    if [ -e "$path" ]; then
        if is_dry_run; then
            info "[DRY-RUN] Would backup: $path"
        else
            cp -r "$path" "$BACKUP_DIR/" 2>/dev/null && \
                success "Backed up: $path"
        fi
    fi
done

# ------------------------------------------------------------------------------
# 4. PASSWORD CHANGE & USER MANAGEMENT
# ------------------------------------------------------------------------------
subheader "User Password Reset"

# Function to check if user is protected
is_protected_user() {
    local user="$1"
    for protected in "${PROTECTED_USERS[@]}"; do
        if [[ "$protected" == "$user" ]]; then
            return 0
        fi
    done
    return 1
}

# Get list of human users (UID >= 1000 or root)
USERS_TO_PROCESS=$(awk -F: '($3 >= 1000 || $1 == "root") {print $1}' /etc/passwd)

for user in $USERS_TO_PROCESS; do
    # Skip nologin users
    shell=$(grep "^$user:" /etc/passwd | awk -F: '{print $7}')
    if [[ "$shell" == */nologin ]] || [[ "$shell" == */false ]]; then
        continue
    fi
    
    # Check if protected
    if is_protected_user "$user"; then
        # Protected user: change password but don't kick
        if is_dry_run; then
            info "[DRY-RUN] Would change password for protected user: $user"
        else
            echo "$user:$NEW_PASS" | chpasswd 2>/dev/null
            if [ $? -eq 0 ]; then
                success "Changed password for (protected): $user"
                log_action "Password changed for protected user: $user"
            else
                error "Failed to change password for: $user"
            fi
        fi
    else
        # Non-protected user: this is suspicious!
        warn "Found non-protected user: $user"
        
        KICK_USER="y"
        if [ "$INTERACTIVE" == "true" ]; then
            echo -e "    Shell: $shell"
            echo -e "    UID: $(id -u "$user" 2>/dev/null || echo 'unknown')"
            
            # Show recent activity
            last_login=$(last "$user" 2>/dev/null | head -n 1 | awk '{print $4, $5, $6, $7}')
            [ -n "$last_login" ] && echo -e "    Last login: $last_login"
            
            if ! confirm "Kick user '$user' and change password?" "y"; then
                KICK_USER="n"
            fi
        fi
        
        if [ "$KICK_USER" == "y" ]; then
            if is_dry_run; then
                info "[DRY-RUN] Would change password and kick user: $user"
            else
                # Change password first
                echo "$user:$NEW_PASS" | chpasswd 2>/dev/null
                
                # Kill all sessions
                pkill -KILL -u "$user" 2>/dev/null
                action "Kicked user: $user"
                log_action "Kicked suspicious user: $user"
            fi
        else
            # Don't kick but still change password
            if ! is_dry_run; then
                echo "$user:$NEW_PASS" | chpasswd 2>/dev/null
                success "Changed password for: $user (kept session)"
            fi
        fi
    fi
done

# ------------------------------------------------------------------------------
# 5. REMOVE SSH AUTHORIZED KEYS
# ------------------------------------------------------------------------------
subheader "SSH Key Cleanup"

SSH_KEY_COUNT=0

# Find all authorized_keys files
while IFS= read -r -d '' keyfile; do
    SSH_KEY_COUNT=$((SSH_KEY_COUNT + 1))
done < <(find /home /root -name "authorized_keys" -print0 2>/dev/null)

if [ $SSH_KEY_COUNT -gt 0 ]; then
    warn "Found $SSH_KEY_COUNT authorized_keys file(s)"
    
    REMOVE_KEYS="y"
    if [ "$INTERACTIVE" == "true" ]; then
        if ! confirm "Remove all SSH authorized_keys files?" "y"; then
            REMOVE_KEYS="n"
        fi
    fi
    
    if [ "$REMOVE_KEYS" == "y" ]; then
        if is_dry_run; then
            find /home -name "authorized_keys" -print 2>/dev/null | while read f; do
                info "[DRY-RUN] Would remove: $f"
            done
            find /root -name "authorized_keys" -print 2>/dev/null | while read f; do
                info "[DRY-RUN] Would remove: $f"
            done
        else
            find /home -name "authorized_keys" -delete 2>/dev/null
            find /root -name "authorized_keys" -delete 2>/dev/null
            action "Removed all authorized_keys files"
            log_action "Removed all SSH authorized_keys"
        fi
    else
        warn "Keeping authorized_keys files."
    fi
else
    success "No authorized_keys files found."
fi

# ------------------------------------------------------------------------------
# 6. ADDITIONAL SECURITY CHECKS
# ------------------------------------------------------------------------------
subheader "Additional Security Checks"

# Check for UID 0 users other than root
info "Checking for unauthorized UID 0 users..."
UID0_USERS=$(awk -F: '($3 == 0 && $1 != "root") {print $1}' /etc/passwd)
if [ -n "$UID0_USERS" ]; then
    error "ALERT: Found non-root users with UID 0!"
    for u in $UID0_USERS; do
        error "  → $u (This is a potential backdoor!)"
        log_action "ALERT: UID 0 user detected: $u"
    done
    
    if [ "$INTERACTIVE" == "true" ]; then
        warn "You should investigate these users immediately!"
    fi
else
    success "No unauthorized UID 0 users found."
fi

# Check for empty passwords
info "Checking for empty passwords..."
EMPTY_PASS=$(awk -F: '($2 == "" || $2 == "!!" || $2 == "*") {print $1}' /etc/shadow 2>/dev/null | grep -v "^#")
if [ -n "$EMPTY_PASS" ]; then
    warn "Users with empty/locked passwords:"
    for u in $EMPTY_PASS; do
        echo "  → $u"
    done
fi

# ------------------------------------------------------------------------------
# 6.5 SSH HARDENING
# ------------------------------------------------------------------------------
subheader "SSH Hardening"

SSHD_CONFIG="/etc/ssh/sshd_config"
SSH_MODIFIED="false"

if [ -f "$SSHD_CONFIG" ]; then
    info "Hardening SSH configuration..."
    
    if ! is_dry_run; then
        cp "$SSHD_CONFIG" "${BACKUP_DIR}/sshd_config.backup"
    fi
    
    CURRENT_ROOT=$(grep -E "^PermitRootLogin" "$SSHD_CONFIG" | awk '{print $2}')
    if [ "$CURRENT_ROOT" == "yes" ]; then
        if ! is_dry_run; then
            sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' "$SSHD_CONFIG"
            success "Disabled root SSH login"
            SSH_MODIFIED="true"
        fi
    elif [ -z "$CURRENT_ROOT" ]; then
        if ! is_dry_run; then
            echo "PermitRootLogin no" >> "$SSHD_CONFIG"
            success "Added PermitRootLogin no"
            SSH_MODIFIED="true"
        fi
    else
        success "Root login already restricted: $CURRENT_ROOT"
    fi
    
    CURRENT_TRIES=$(grep -E "^MaxAuthTries" "$SSHD_CONFIG" | awk '{print $2}')
    if [ -z "$CURRENT_TRIES" ] || [ "$CURRENT_TRIES" -gt 4 ]; then
        if ! is_dry_run; then
            if [ -n "$CURRENT_TRIES" ]; then
                sed -i 's/^MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"
            else
                echo "MaxAuthTries 3" >> "$SSHD_CONFIG"
            fi
            success "Set MaxAuthTries to 3"
            SSH_MODIFIED="true"
        fi
    fi
    
    CURRENT_EMPTY=$(grep -E "^PermitEmptyPasswords" "$SSHD_CONFIG" | awk '{print $2}')
    if [ "$CURRENT_EMPTY" != "no" ]; then
        if ! is_dry_run; then
            if grep -q "^PermitEmptyPasswords" "$SSHD_CONFIG"; then
                sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSHD_CONFIG"
            else
                echo "PermitEmptyPasswords no" >> "$SSHD_CONFIG"
            fi
            success "Disabled empty password login"
            SSH_MODIFIED="true"
        fi
    fi
    
    if [ "$SSH_MODIFIED" == "true" ] && ! is_dry_run; then
        info "Restarting SSH service..."
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
        success "SSH service restarted"
    fi
else
    warn "sshd_config not found"
fi

# ------------------------------------------------------------------------------
# 7. SUMMARY
# ------------------------------------------------------------------------------
subheader "Hardening Summary"

echo ""
if is_dry_run; then
    info "[DRY-RUN] No changes were made."
else
    success "Initial hardening completed!"
    info "Backup location: $BACKUP_DIR"
    info "Check logs at: $LOG_FILE"
fi