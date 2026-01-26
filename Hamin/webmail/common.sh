#!/bin/bash
# ==============================================================================
# SCRIPT: common.sh (Shared Utility Library)
# PURPOSE: Provides common functions for all CCDC defense scripts
# USAGE: source ./common.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. COLOR CODES
# ------------------------------------------------------------------------------
export RED='\e[31m'
export GREEN='\e[32m'
export YELLOW='\e[33m'
export BLUE='\e[34m'
export MAGENTA='\e[35m'
export CYAN='\e[36m'
export WHITE='\e[37m'
export BOLD='\e[1m'
export NC='\e[0m' # No Color (Reset)

# ------------------------------------------------------------------------------
# 2. GLOBAL VARIABLES
# ------------------------------------------------------------------------------
SCRIPT_NAME="${0##*/}"
LOG_DIR="${LOG_DIR:-/var/log/ccdc}"
LOG_FILE="${LOG_DIR}/ccdc_$(date +%Y%m%d).log"
DRY_RUN="${DRY_RUN:-false}"
INTERACTIVE="${INTERACTIVE:-true}"
VERBOSE="${VERBOSE:-false}"

# ------------------------------------------------------------------------------
# 3. LOGGING FUNCTIONS
# ------------------------------------------------------------------------------

# Initialize logging directory
init_logging() {
    if [ "$DRY_RUN" != "true" ]; then
        mkdir -p "$LOG_DIR" 2>/dev/null
        chmod 700 "$LOG_DIR" 2>/dev/null
    fi
}

# Log message to file and optionally to stdout
# Usage: log "INFO" "Message here"
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$SCRIPT_NAME] [$level] $message"
    
    # Write to log file (unless dry-run)
    if [ "$DRY_RUN" != "true" ] && [ -d "$LOG_DIR" ]; then
        echo "$log_entry" >> "$LOG_FILE" 2>/dev/null
    fi
    
    # Verbose mode: also print to stdout
    if [ "$VERBOSE" == "true" ]; then
        echo "$log_entry"
    fi
}

# Shorthand logging functions
log_info()    { log "INFO" "$1"; }
log_warn()    { log "WARN" "$1"; }
log_error()   { log "ERROR" "$1"; }
log_action()  { log "ACTION" "$1"; }

# ------------------------------------------------------------------------------
# 4. OUTPUT FUNCTIONS (Console) - WITH TIMESTAMPS FOR CCDC REPORTS
# ------------------------------------------------------------------------------

# Get current timestamp
get_timestamp() {
    date '+%H:%M:%S'
}

# Print with prefix, timestamp, and color
# Usage: print_msg "INFO" "Message" "$GREEN"
print_msg() {
    local prefix="$1"
    local message="$2"
    local color="${3:-$NC}"
    local ts=$(get_timestamp)
    echo -e "${WHITE}[${ts}]${NC} ${color}[${prefix}]${NC} ${message}"
}

# Convenience wrappers (all include timestamps)
info()    { print_msg "*" "$1" "$CYAN"; log_info "$1"; }
success() { print_msg "OK" "$1" "$GREEN"; log_info "$1"; }
warn()    { print_msg "!" "$1" "$YELLOW"; log_warn "$1"; }
error()   { print_msg "ERROR" "$1" "$RED"; log_error "$1"; }
action()  { print_msg "ACTION" "$1" "$MAGENTA"; log_action "$1"; }

# Print section header with timestamp
header() {
    local title="$1"
    local ts=$(get_timestamp)
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}[${ts}]${NC} ${BOLD}${BLUE}$title${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Print sub-section with timestamp
subheader() {
    local ts=$(get_timestamp)
    echo -e "\n${WHITE}[${ts}]${NC} ${BOLD}[${1}]${NC}"
}

# ------------------------------------------------------------------------------
# 5. USER INTERACTION
# ------------------------------------------------------------------------------

# Confirm prompt with default option
# Usage: confirm "Do you want to proceed?" "y" && do_something
# Returns: 0 (true) if confirmed, 1 (false) if declined
confirm() {
    local prompt="$1"
    local default="${2:-n}"  # Default: no
    
    # Skip in non-interactive mode
    if [ "$INTERACTIVE" != "true" ]; then
        [ "$default" == "y" ] && return 0 || return 1
    fi
    
    local options
    if [ "$default" == "y" ]; then
        options="[Y/n]"
    else
        options="[y/N]"
    fi
    
    while true; do
        echo -en "${YELLOW}[?]${NC} ${prompt} ${options}: "
        read -r response
        response="${response:-$default}"
        
        case "${response,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     echo "Please answer y or n." ;;
        esac
    done
}

# Prompt for password with confirmation
# Usage: NEW_PASS=$(prompt_password "Enter new password")
prompt_password() {
    local prompt="${1:-Enter password}"
    local pass1 pass2
    
    while true; do
        echo -en "${YELLOW}[?]${NC} ${prompt}: "
        read -rs pass1
        echo ""
        
        echo -en "${YELLOW}[?]${NC} Confirm password: "
        read -rs pass2
        echo ""
        
        if [ "$pass1" != "$pass2" ]; then
            error "Passwords do not match. Try again."
            continue
        fi
        
        if [ -z "$pass1" ]; then
            error "Password cannot be empty."
            continue
        fi
        
        if [ ${#pass1} -lt 8 ]; then
            warn "Password is less than 8 characters."
            confirm "Use this password anyway?" || continue
        fi
        
        echo "$pass1"
        return 0
    done
}

# Prompt for input with default
# Usage: value=$(prompt_input "Enter value" "default")
prompt_input() {
    local prompt="$1"
    local default="$2"
    local value
    
    if [ -n "$default" ]; then
        echo -en "${YELLOW}[?]${NC} ${prompt} [${default}]: "
    else
        echo -en "${YELLOW}[?]${NC} ${prompt}: "
    fi
    
    read -r value
    echo "${value:-$default}"
}

# ------------------------------------------------------------------------------
# 6. DRY-RUN SUPPORT
# ------------------------------------------------------------------------------

# Execute command or just print it (dry-run mode)
# Usage: run_cmd "iptables -A INPUT -j DROP"
run_cmd() {
    local cmd="$1"
    
    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would execute: $cmd"
        log_info "[DRY-RUN] $cmd"
        return 0
    else
        log_action "Executing: $cmd"
        eval "$cmd"
        return $?
    fi
}

# Check if dry-run mode is active
is_dry_run() {
    [ "$DRY_RUN" == "true" ]
}

# ------------------------------------------------------------------------------
# 7. ROLLBACK SUPPORT
# ------------------------------------------------------------------------------

ROLLBACK_DIR="/root/.ccdc_rollback"

# Create rollback point
# Usage: create_rollback_point "firewall"
create_rollback_point() {
    local name="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local rollback_path="${ROLLBACK_DIR}/${name}_${timestamp}"
    
    if is_dry_run; then
        info "[DRY-RUN] Would create rollback point: $rollback_path"
        return 0
    fi
    
    mkdir -p "$rollback_path"
    echo "$rollback_path"
}

# Save iptables rules for rollback
backup_iptables() {
    local rollback_path="$1"
    
    if is_dry_run; then
        info "[DRY-RUN] Would backup iptables rules"
        return 0
    fi
    
    iptables-save > "${rollback_path}/iptables.rules" 2>/dev/null
    ip6tables-save > "${rollback_path}/ip6tables.rules" 2>/dev/null
    info "Backed up iptables rules to: $rollback_path"
}

# Restore iptables from backup
restore_iptables() {
    local rollback_path="$1"
    
    if [ -f "${rollback_path}/iptables.rules" ]; then
        iptables-restore < "${rollback_path}/iptables.rules"
        info "Restored iptables from: $rollback_path"
    fi
    
    if [ -f "${rollback_path}/ip6tables.rules" ]; then
        ip6tables-restore < "${rollback_path}/ip6tables.rules"
        info "Restored ip6tables from: $rollback_path"
    fi
}

# ------------------------------------------------------------------------------
# 7.5. FIREWALLD SUPPORT (Fedora 42)
# ------------------------------------------------------------------------------

# Save firewalld rules for rollback
backup_firewalld() {
    local rollback_path="$1"
    
    if is_dry_run; then
        info "[DRY-RUN] Would backup firewalld rules"
        return 0
    fi
    
    if ! command_exists firewall-cmd; then
        warn "firewall-cmd not found"
        return 1
    fi
    
    firewall-cmd --list-all --permanent > "${rollback_path}/firewalld.conf" 2>/dev/null
    firewall-cmd --list-ports --permanent > "${rollback_path}/firewalld-ports.txt" 2>/dev/null
    firewall-cmd --list-services --permanent > "${rollback_path}/firewalld-services.txt" 2>/dev/null
    firewall-cmd --list-rich-rules --permanent > "${rollback_path}/firewalld-rich-rules.txt" 2>/dev/null
    
    info "Backed up firewalld rules to: $rollback_path"
}

# Restore firewalld from backup
restore_firewalld() {
    local rollback_path="$1"
    
    if ! command_exists firewall-cmd; then
        warn "firewall-cmd not found"
        return 1
    fi
    
    if [ -f "${rollback_path}/firewalld-ports.txt" ]; then
        for port in $(firewall-cmd --list-ports --permanent 2>/dev/null); do
            firewall-cmd --permanent --remove-port="$port" 2>/dev/null
        done
        
        while read -r port; do
            [ -n "$port" ] && firewall-cmd --permanent --add-port="$port" 2>/dev/null
        done < "${rollback_path}/firewalld-ports.txt"
    fi
    
    firewall-cmd --reload 2>/dev/null
    info "Restored firewalld from: $rollback_path"
}

# Run firewall-cmd with dry-run support
run_firewall_cmd() {
    local cmd="$1"
    
    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would execute: firewall-cmd $cmd"
        log_info "[DRY-RUN] firewall-cmd $cmd"
        return 0
    else
        log_action "Executing: firewall-cmd $cmd"
        eval "firewall-cmd $cmd"
        return $?
    fi
}

# ------------------------------------------------------------------------------
# 8. VALIDATION & CHECKS
# ------------------------------------------------------------------------------

# Check if running as root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (sudo)."
        exit 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if we're in a Docker container
is_docker() {
    [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# Get current SSH user (to avoid kicking ourselves)
get_current_admin() {
    local admin="${SUDO_USER:-$(who am i 2>/dev/null | awk '{print $1}')}"
    [ -z "$admin" ] && admin="root"
    echo "$admin"
}

# ------------------------------------------------------------------------------
# 9. BANNER
# ------------------------------------------------------------------------------

print_banner() {
    local version="${1:-2.0}"
    local mode_str=""
    
    [ "$DRY_RUN" == "true" ] && mode_str+="DRY-RUN "
    [ "$INTERACTIVE" == "true" ] && mode_str+="INTERACTIVE " || mode_str+="AUTO "
    
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              CCDC DEFENSE TOOLKIT v${version}                      ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  Mode: ${mode_str}                                        ║"
    echo -e "║  Logging: ${LOG_FILE}         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ------------------------------------------------------------------------------
# 10. INITIALIZATION
# ------------------------------------------------------------------------------

# Auto-initialize logging when sourced
init_logging
