#!/bin/bash
# ==============================================================================
# SCRIPT: rollback.sh (Configuration Rollback - firewalld)
# PURPOSE: Restore system to a previous state from backup
# USAGE: sudo ./rollback.sh [backup_path]
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

require_root

BACKUP_BASE="/root"
ROLLBACK_BASE="/root/.ccdc_rollback"

find_backups() {
    echo ""
    info "Available backups:"
    echo ""
    
    local count=0
    
    for backup in "$BACKUP_BASE"/ccdc_backup_*; do
        if [ -d "$backup" ]; then
            count=$((count + 1))
            local size=$(du -sh "$backup" 2>/dev/null | awk '{print $1}')
            echo "  [$count] $backup (Size: $size)"
        fi
    done
    
    for backup in "$ROLLBACK_BASE"/firewall_*; do
        if [ -d "$backup" ]; then
            count=$((count + 1))
            echo "  [$count] $backup (Firewall rules)"
        fi
    done
    
    if [ "$count" -eq 0 ]; then
        warn "No backups found!"
        exit 1
    fi
    
    echo ""
    echo "  Total: $count backup(s)"
}

rollback_firewall() {
    local backup_path="$1"
    subheader "Firewall Rollback (firewalld)"
    
    if [ -f "${backup_path}/firewalld-ports.txt" ]; then
        restore_firewalld "$backup_path"
        success "Firewall rules restored"
    else
        warn "No firewalld backup found"
    fi
}

rollback_config() {
    local backup_path="$1"
    subheader "Configuration Rollback"
    
    warn "This will overwrite current configurations!"
    ls -la "$backup_path" 2>/dev/null
    
    if ! confirm "Proceed with rollback?" "n"; then
        info "Cancelled"
        return
    fi
    
    for item in "$backup_path"/*; do
        [ -e "$item" ] || continue
        local name=$(basename "$item")
        local target=""
        
        case "$name" in
            "ssh")      target="/etc/ssh" ;;
            "passwd")   target="/etc/passwd" ;;
            "shadow")   target="/etc/shadow" ;;
            "postfix")  target="/etc/postfix" ;;
            "dovecot")  target="/etc/dovecot" ;;
            "httpd")    target="/etc/httpd" ;;
            "nginx")    target="/etc/nginx" ;;
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
    
    if confirm "Restart mail services?" "y"; then
        systemctl restart postfix 2>/dev/null
        systemctl restart dovecot 2>/dev/null
        success "Mail services restarted"
    fi
}

panic_rollback() {
    header "PANIC ROLLBACK"
    warn "This will open ALL firewall rules!"
    
    if ! confirm "Proceed?" "n"; then
        exit 0
    fi
    
    firewall-cmd --set-default-zone=trusted
    firewall-cmd --reload
    
    success "Firewall set to trusted zone!"
    warn "System is UNPROTECTED!"
}

# Main
print_banner "2.0"
header "ROLLBACK UTILITY (firewalld)"

if [ -n "$1" ]; then
    if [ "$1" == "--panic" ]; then
        panic_rollback
        exit 0
    elif [ -d "$1" ]; then
        rollback_firewall "$1"
    else
        error "Path not found: $1"
        exit 1
    fi
else
    find_backups
    echo ""
    echo "Options:"
    echo "  [1] Restore firewall"
    echo "  [2] Restore configuration"
    echo "  [3] PANIC - Open all"
    echo "  [q] Quit"
    echo ""
    
    choice=$(prompt_input "Select option")
    
    case "$choice" in
        1)
            path=$(prompt_input "Enter firewall backup path")
            [ -d "$path" ] && rollback_firewall "$path" || error "Not found"
            ;;
        2)
            path=$(prompt_input "Enter config backup path")
            [ -d "$path" ] && rollback_config "$path" || error "Not found"
            ;;
        3)
            panic_rollback
            ;;
        q|Q)
            exit 0
            ;;
    esac
fi

success "Rollback completed!"
