#!/bin/bash
# ==============================================================================
# SCRIPT: audit.sh (Security Audit & Backdoor Detection)
# PURPOSE: Scan system for persistence mechanisms, backdoors, and anomalies
# USAGE: sudo ./audit.sh [--quick] [--report]
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load dependencies
source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

require_root

# ------------------------------------------------------------------------------
# 1. ARGUMENT PARSING
# ------------------------------------------------------------------------------
QUICK_MODE="false"
GENERATE_REPORT="false"
REPORT_FILE=""

for arg in "$@"; do
    case $arg in
        --quick)   QUICK_MODE="true" ;;
        --report)  GENERATE_REPORT="true" ;;
    esac
done

if [ "$GENERATE_REPORT" == "true" ]; then
    REPORT_FILE="${LOG_DIR}/audit_report_$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p "$LOG_DIR" 2>/dev/null
fi

# Report helper
report() {
    local msg="$1"
    echo "$msg"
    if [ -n "$REPORT_FILE" ]; then
        echo "$msg" >> "$REPORT_FILE"
    fi
}

# ------------------------------------------------------------------------------
# 2. FINDINGS COUNTER
# ------------------------------------------------------------------------------
WARNINGS=0
CRITICAL=0

add_warning() {
    WARNINGS=$((WARNINGS + 1))
    log_warn "$1"
}

add_critical() {
    CRITICAL=$((CRITICAL + 1))
    log_error "CRITICAL: $1"
}

# ------------------------------------------------------------------------------
# 3. AUDIT FUNCTIONS
# ------------------------------------------------------------------------------

# 3.1 Check for UID 0 users (backdoor accounts)
audit_uid0() {
    subheader "UID 0 Accounts (Superuser Check)"
    
    local uid0_users=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)
    
    for user in $uid0_users; do
        if [ "$user" == "root" ]; then
            report "   ${GREEN}✓${NC} root - OK"
        else
            report "   ${RED}✗ CRITICAL: $user has UID 0 (possible backdoor!)${NC}"
            add_critical "UID 0 user found: $user"
        fi
    done
}

# 3.2 Check for password-less accounts
audit_passwords() {
    subheader "Password Security"
    
    # Empty passwords
    local empty=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null)
    if [ -n "$empty" ]; then
        for user in $empty; do
            report "   ${RED}✗ WARNING: $user has NO PASSWORD${NC}"
            add_critical "Empty password: $user"
        done
    else
        report "   ${GREEN}✓${NC} No accounts with empty passwords"
    fi
}

# 3.3 Check /etc/sudoers for suspicious entries
audit_sudoers() {
    subheader "Sudoers Configuration"
    
    # Check main sudoers
    if [ -f /etc/sudoers ]; then
        local nopasswd=$(grep -i "NOPASSWD" /etc/sudoers 2>/dev/null | grep -v "^#")
        if [ -n "$nopasswd" ]; then
            report "   ${YELLOW}! NOPASSWD entries found:${NC}"
            echo "$nopasswd" | while read line; do
                report "     $line"
                add_warning "NOPASSWD in sudoers: $line"
            done
        else
            report "   ${GREEN}✓${NC} No NOPASSWD entries"
        fi
    fi
    
    # Check sudoers.d
    if [ -d /etc/sudoers.d ]; then
        local count=$(ls -1 /etc/sudoers.d/ 2>/dev/null | wc -l)
        report "   Files in /etc/sudoers.d/: $count"
        
        for f in /etc/sudoers.d/*; do
            [ -f "$f" ] || continue
            local nopasswd=$(grep -i "NOPASSWD" "$f" 2>/dev/null | grep -v "^#")
            if [ -n "$nopasswd" ]; then
                report "   ${YELLOW}! $f has NOPASSWD:${NC}"
                add_warning "NOPASSWD in $f"
            fi
        done
    fi
}

# 3.4 Check cron jobs for persistence
audit_cron() {
    subheader "Scheduled Tasks (Cron)"
    
    local suspicious=0
    
    # System crontab
    if [ -f /etc/crontab ]; then
        report "   Checking /etc/crontab..."
        local entries=$(grep -v "^#" /etc/crontab | grep -v "^$" | grep -v "SHELL=" | grep -v "PATH=" | wc -l)
        report "     Found $entries active entries"
    fi
    
    # Cron directories
    for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
        if [ -d "$dir" ]; then
            local count=$(ls -1 "$dir" 2>/dev/null | wc -l)
            report "   $dir: $count scripts"
        fi
    done
    
    # User crontabs
    report ""
    report "   User crontabs:"
    for user_cron in /var/spool/cron/crontabs/*; do
        [ -f "$user_cron" ] || continue
        local user=$(basename "$user_cron")
        local entries=$(grep -v "^#" "$user_cron" 2>/dev/null | grep -v "^$" | wc -l)
        if [ "$entries" -gt 0 ]; then
            report "   ${YELLOW}! $user has $entries cron entries${NC}"
            add_warning "User cron: $user ($entries entries)"
        fi
    done
    
    # Check for suspicious cron patterns
    report ""
    report "   Checking for suspicious patterns..."
    
    for cron_path in /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/*; do
        [ -f "$cron_path" ] || continue
        
        # Look for reverse shells, wget, curl, nc, etc.
        local sus=$(grep -E "(bash -i|/dev/tcp|nc |ncat |wget |curl.*\||python.*socket)" "$cron_path" 2>/dev/null)
        if [ -n "$sus" ]; then
            report "   ${RED}✗ CRITICAL: Suspicious command in $cron_path${NC}"
            report "     $sus"
            add_critical "Suspicious cron in $cron_path"
        fi
    done
}

# 3.5 Check systemd timers
audit_systemd_timers() {
    [ "$QUICK_MODE" == "true" ] && return
    
    subheader "Systemd Timers"
    
    if ! command_exists systemctl; then
        report "   [i] Systemd not available"
        return
    fi
    
    local timers=$(systemctl list-timers --all --no-pager 2>/dev/null | grep -v "^NEXT" | grep -v "^$" | grep -v "timers listed")
    report "   Active timers:"
    echo "$timers" | head -n 10 | while read line; do
        report "     $line"
    done
}

# 3.6 Check SUID/SGID binaries
audit_suid() {
    [ "$QUICK_MODE" == "true" ] && return
    
    subheader "SUID/SGID Binaries"
    
    report "   Scanning for SUID binaries..."
    
    # Find all SUID binaries
    local suid_files=$(find / -perm -4000 -type f 2>/dev/null)
    
    for file in $suid_files; do
        local is_known="false"
        
        # Check against known good list
        for known in "${KNOWN_SUID_BINARIES[@]}"; do
            if [ "$file" == "$known" ]; then
                is_known="true"
                break
            fi
        done
        
        if [ "$is_known" == "false" ]; then
            report "   ${YELLOW}! Unknown SUID: $file${NC}"
            add_warning "Unknown SUID: $file"
        fi
    done
    
    # Count total
    local total=$(echo "$suid_files" | wc -l)
    report "   Total SUID binaries: $total"
}

# 3.7 Check SSH configuration
audit_ssh() {
    subheader "SSH Configuration"
    
    local sshd_config="/etc/ssh/sshd_config"
    
    if [ ! -f "$sshd_config" ]; then
        report "   [i] sshd_config not found"
        return
    fi
    
    # Root login
    local root_login=$(grep -i "^PermitRootLogin" "$sshd_config" | awk '{print $2}')
    if [ "$root_login" == "yes" ]; then
        report "   ${YELLOW}! PermitRootLogin is enabled${NC}"
        add_warning "Root SSH login enabled"
    else
        report "   ${GREEN}✓${NC} Root login: ${root_login:-default}"
    fi
    
    # Password authentication
    local pass_auth=$(grep -i "^PasswordAuthentication" "$sshd_config" | awk '{print $2}')
    report "   Password auth: ${pass_auth:-default}"
    
    # Port
    local ssh_port=$(grep -i "^Port" "$sshd_config" | awk '{print $2}')
    report "   SSH Port: ${ssh_port:-22}"
    
    # Check authorized_keys files
    report ""
    report "   Checking authorized_keys..."
    local auth_key_count=$(find /home /root -name "authorized_keys" 2>/dev/null | wc -l)
    if [ "$auth_key_count" -gt 0 ]; then
        report "   ${YELLOW}! Found $auth_key_count authorized_keys file(s)${NC}"
        find /home /root -name "authorized_keys" 2>/dev/null | while read f; do
            local keys=$(wc -l < "$f")
            report "     $f: $keys key(s)"
        done
    else
        report "   ${GREEN}✓${NC} No authorized_keys files"
    fi
}

# 3.8 Check for listening processes
audit_network() {
    subheader "Network Listeners"
    
    report "   Listening ports and processes:"
    
    if command_exists ss; then
        ss -tulnp 2>/dev/null | grep LISTEN | while read line; do
            report "     $line"
        done
    elif command_exists netstat; then
        netstat -tulnp 2>/dev/null | grep LISTEN | while read line; do
            report "     $line"
        done
    fi
}

# 3.9 Check for suspicious processes
audit_processes() {
    [ "$QUICK_MODE" == "true" ] && return
    
    subheader "Suspicious Processes"
    
    # Processes running as root
    report "   High-privilege processes (running as root):"
    ps aux 2>/dev/null | awk '$1=="root" {print "     " $11}' | sort | uniq | head -n 15
    
    # Common backdoor process names
    report ""
    report "   Checking for known backdoor patterns..."
    
    local sus_procs=$(ps aux 2>/dev/null | grep -iE "(nc -l|ncat|socat|cryptominer|xmrig|/tmp/|/dev/shm/)" | grep -v grep)
    if [ -n "$sus_procs" ]; then
        report "   ${RED}✗ Suspicious processes found:${NC}"
        echo "$sus_procs" | while read line; do
            report "     $line"
            add_critical "Suspicious process: $line"
        done
    else
        report "   ${GREEN}✓${NC} No obvious backdoor processes"
    fi
}

# 3.10 Check /tmp and /dev/shm for executables
audit_temp_dirs() {
    [ "$QUICK_MODE" == "true" ] && return
    
    subheader "Temporary Directory Audit"
    
    for dir in /tmp /dev/shm /var/tmp; do
        if [ -d "$dir" ]; then
            local exec_count=$(find "$dir" -type f -executable 2>/dev/null | wc -l)
            if [ "$exec_count" -gt 0 ]; then
                report "   ${YELLOW}! $dir has $exec_count executable file(s)${NC}"
                find "$dir" -type f -executable 2>/dev/null | head -n 5 | while read f; do
                    report "     - $f"
                done
                add_warning "Executables in $dir"
            else
                report "   ${GREEN}✓${NC} $dir: No executables"
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# 4. MAIN EXECUTION
# ------------------------------------------------------------------------------

print_banner "2.0"
header "SECURITY AUDIT"

if [ "$QUICK_MODE" == "true" ]; then
    info "Running in QUICK mode (some checks skipped)"
fi

if [ -n "$REPORT_FILE" ]; then
    info "Report will be saved to: $REPORT_FILE"
    echo "CCDC Security Audit Report" > "$REPORT_FILE"
    echo "Generated: $(date)" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# Run all audits
audit_uid0
audit_passwords
audit_sudoers
audit_cron
audit_systemd_timers
audit_suid
audit_ssh
audit_network
audit_processes
audit_temp_dirs

# ------------------------------------------------------------------------------
# 5. SUMMARY
# ------------------------------------------------------------------------------
header "AUDIT SUMMARY"

echo ""
if [ "$CRITICAL" -gt 0 ]; then
    report "${RED}${BOLD}CRITICAL FINDINGS: $CRITICAL${NC}"
fi

if [ "$WARNINGS" -gt 0 ]; then
    report "${YELLOW}${BOLD}WARNINGS: $WARNINGS${NC}"
fi

if [ "$CRITICAL" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    report "${GREEN}${BOLD}No issues found!${NC}"
fi

echo ""

if [ -n "$REPORT_FILE" ]; then
    echo "" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    echo "Critical: $CRITICAL | Warnings: $WARNINGS" >> "$REPORT_FILE"
    success "Report saved to: $REPORT_FILE"
fi

# Exit with appropriate code
if [ "$CRITICAL" -gt 0 ]; then
    exit 2
elif [ "$WARNINGS" -gt 0 ]; then
    exit 1
else
    exit 0
fi
