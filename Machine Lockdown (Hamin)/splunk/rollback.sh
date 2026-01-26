#!/bin/bash
# ==============================================================================
# SCRIPT: rollback.sh (Configuration Rollback - firewalld)
# PURPOSE: Restore system to a previous state from backup
# USAGE: sudo ./rollback.sh [backup_path]
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load dependencies
source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

require_root

# ------------------------------------------------------------------------------
# 1. FIND AVAILABLE BACKUPS
# ------------------------------------------------------------------------------
BACKUP_BASE="/root"
ROLLBACK_BASE="/root/.ccdc_rollback"

find_backups() {
    echo ""
    info "Available backups:"
    echo ""
    
    local count=0
    
    # Configuration backups from init_setting.sh
    for backup in "$BACKUP_BASE"/ccdc_backup_*; do
        if [ -d "$backup" ]; then
            count=$((count + 1))
            local name=$(basename "$backup")
            local date=$(echo "$name" | sed 's/ccdc_backup_//')
            local size=$(du -sh "$backup" 2>/dev/null | awk '{print $1}')
            echo "  [$count] $backup"
            echo "      Type: Configuration backup"
            echo "      Size: $size"
            echo ""
        fi
    done
    
    # Firewall rollback points
    for backup in "$ROLLBACK_BASE"/firewall_*; do
        if [ -d "$backup" ]; then
            count=$((count + 1))
            local name=$(basename "$backup")
            echo "  [$count] $backup"
            echo "      Type: Firewall rules (firewalld)"
            echo ""
        fi
    done
    
    if [ "$count" -eq 0 ]; then
        warn "No backups found!"
        exit 1
    fi
    
    echo "  Total: $count backup(s)"
}

# ------------------------------------------------------------------------------
# 2. ROLLBACK FUNCTIONS
# ------------------------------------------------------------------------------

rollback_firewall() {
    local backup_path="$1"
    
    subheader "Firewall Rollback (firewalld)"
    
    if [ -f "${backup_path}/firewalld-ports.txt" ]; then
        restore_firewalld "$backup_path"
        success "Firewall rules restored"
    else
        warn "No firewalld backup found in $backup_path"
    fi
}

rollback_config() {
    local backup_path="$1"
    
    subheader "Configuration Rollback"
    
    warn "This will overwrite current configurations!"
    echo ""
    echo "Files to restore:"
    ls -la "$backup_path" 2>/dev/null
    echo ""
    
    if ! confirm "Proceed with configuration rollback?" "n"; then
        info "Rollback cancelled"
        return
    fi
    
    # Restore each backed up path
    for item in "$backup_path"/*; do
        [ -e "$item" ] || continue
        
        local name=$(basename "$item")
        local target=""
        
        # Determine original location
        case "$name" in
            "ssh")          target="/etc/ssh" ;;
            "passwd")       target="/etc/passwd" ;;
            "shadow")       target="/etc/shadow" ;;
            "group")        target="/etc/group" ;;
            "sudoers")      target="/etc/sudoers" ;;
            "sudoers.d")    target="/etc/sudoers.d" ;;
            # Splunk paths
            "local")        target="${SPLUNK_HOME:-/opt/splunk}/etc/system/local" ;;
            "apps")         target="${SPLUNK_HOME:-/opt/splunk}/etc/apps" ;;
            "users")        target="${SPLUNK_HOME:-/opt/splunk}/etc/users" ;;
        esac
        
        if [ -n "$target" ]; then
            info "Restoring: $name -> $target"
            
            if [ -d "$item" ]; then
                rm -rf "$target" 2>/dev/null
                cp -r "$item" "$target"
            else
                cp "$item" "$target"
            fi
            
            success "Restored: $target"
        fi
    done
    
    # Restart affected services
    echo ""
    if confirm "Restart SSH service?" "y"; then
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
        success "SSH restarted"
    fi
    
    if confirm "Restart Splunk?" "y"; then
        "${SPLUNK_HOME:-/opt/splunk}/bin/splunk" restart 2>/dev/null
        success "Splunk restarted"
    fi
}

# ------------------------------------------------------------------------------
# 3. PANIC ROLLBACK (Reset firewalld to trusted)
# ------------------------------------------------------------------------------

panic_rollback() {
    header "PANIC ROLLBACK"
    
    warn "This will open ALL firewall rules!"
    
    if ! confirm "Proceed with panic rollback?" "n"; then
        info "Cancelled"
        exit 0
    fi
    
    # Set zone to trusted (allow all)
    firewall-cmd --set-default-zone=trusted
    firewall-cmd --reload
    
    success "Firewall set to trusted zone (all traffic allowed)!"
    warn "System is now UNPROTECTED. Apply proper rules ASAP!"
}

# ------------------------------------------------------------------------------
# 4. MAIN MENU
# ------------------------------------------------------------------------------

print_banner "2.0"
header "ROLLBACK UTILITY (firewalld)"

# Check if specific backup path provided
if [ -n "$1" ]; then
    if [ "$1" == "--panic" ]; then
        panic_rollback
        exit 0
    elif [ -d "$1" ]; then
        SELECTED_BACKUP="$1"
    else
        error "Backup path not found: $1"
        exit 1
    fi
else
    # Interactive selection
    find_backups
    echo ""
    
    echo "Options:"
    echo "  [1] Restore firewall from rollback point"
    echo "  [2] Restore configuration from backup"
    echo "  [3] PANIC - Open all firewall rules"
    echo "  [q] Quit"
    echo ""
    
    choice=$(prompt_input "Select option")
    
    case "$choice" in
        1)
            echo ""
            backup_path=$(prompt_input "Enter firewall rollback path (e.g., /root/.ccdc_rollback/firewall_...)")
            if [ -d "$backup_path" ]; then
                rollback_firewall "$backup_path"
            else
                error "Path not found: $backup_path"
            fi
            ;;
        2)
            echo ""
            backup_path=$(prompt_input "Enter config backup path (e.g., /root/ccdc_backup_...)")
            if [ -d "$backup_path" ]; then
                rollback_config "$backup_path"
            else
                error "Path not found: $backup_path"
            fi
            ;;
        3)
            panic_rollback
            ;;
        q|Q)
            info "Exiting"
            exit 0
            ;;
        *)
            error "Invalid option"
            exit 1
            ;;
    esac
fi

echo ""
success "Rollback completed!"
