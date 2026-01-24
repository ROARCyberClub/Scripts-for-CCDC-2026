#!/bin/bash
# ==============================================================================
# SCRIPT: deploy.sh (Interactive Deployment)
# PURPOSE: Main entry point for CCDC defense deployment
# USAGE: sudo ./deploy.sh [--dry-run] [--auto] [--help]
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ------------------------------------------------------------------------------
# 1. ARGUMENT PARSING
# ------------------------------------------------------------------------------
show_help() {
    echo "CCDC Defense Deployment Script"
    echo ""
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run     Show what would happen without making changes"
    echo "  --auto        Non-interactive mode (skip confirmations)"
    echo "  --verbose     Show detailed logging output"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo $0                  # Interactive deployment"
    echo "  sudo $0 --dry-run        # Preview changes only"
    echo "  sudo $0 --auto           # Automated deployment (use with caution)"
    exit 0
}

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)  export DRY_RUN="true" ;;
        --auto)     export INTERACTIVE="false" ;;
        --verbose)  export VERBOSE="true" ;;
        --help|-h)  show_help ;;
        *)          echo "Unknown option: $arg"; show_help ;;
    esac
done

# ------------------------------------------------------------------------------
# 2. ROOT CHECK & PREPARATION
# ------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must be run as root (sudo)."
    exit 1
fi

# Sanitize scripts (remove Windows line endings)
sed -i 's/\r$//' *.sh 2>/dev/null || true
chmod +x *.sh

# Load configuration
if [ ! -f "./vars.sh" ]; then
    echo "[ERROR] vars.sh not found. Please create it first."
    exit 1
fi
source ./vars.sh

# Load common utilities
if [ -f "./common.sh" ]; then
    source ./common.sh
else
    echo "[ERROR] common.sh not found. Please ensure all scripts are present."
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. OS DETECTION
# ------------------------------------------------------------------------------
header "SYSTEM DETECTION"

PKG_MANAGER=""
if command_exists apt-get; then
    PKG_MANAGER="apt-get"
    info "Detected: Debian/Ubuntu based (apt-get)"
elif command_exists dnf; then
    PKG_MANAGER="dnf"
    info "Detected: RHEL/CentOS/Rocky (dnf)"
elif command_exists yum; then
    PKG_MANAGER="yum"
    info "Detected: RHEL/CentOS Legacy (yum)"
elif command_exists pacman; then
    PKG_MANAGER="pacman"
    info "Detected: Arch Linux (pacman)"
elif command_exists zypper; then
    PKG_MANAGER="zypper"
    info "Detected: SUSE/OpenSUSE (zypper)"
else
    warn "Unknown OS. Some features may not work."
fi

# Docker detection
if is_docker || [ "$USE_DOCKER" == "true" ]; then
    USE_DOCKER="true"
    warn "Docker environment detected. FORWARD chain will be preserved."
fi

# ------------------------------------------------------------------------------
# 4. CONFIGURATION VALIDATION
# ------------------------------------------------------------------------------
header "CONFIGURATION CHECK"

# Check scoreboard IPs
if [[ "${SCOREBOARD_IPS[0]}" == "10.x.x.x" ]] || [[ "${SCOREBOARD_IPS[0]}" == "10.0.0.1" ]]; then
    warn "Scoreboard IP is set to placeholder: ${SCOREBOARD_IPS[*]}"
    if [ "$INTERACTIVE" == "true" ]; then
        new_ip=$(prompt_input "Enter actual Scoreboard IP (or press Enter to continue)")
        if [ -n "$new_ip" ]; then
            SCOREBOARD_IPS=("$new_ip")
            info "Scoreboard IP updated to: $new_ip"
        fi
    fi
fi

info "Scoreboard IPs: ${SCOREBOARD_IPS[*]}"
info "SSH Port: $SSH_PORT"
info "Allowed Protocols: ${ALLOWED_PROTOCOLS[*]}"
info "Protected Services: ${PROTECTED_SERVICES[*]}"
info "Trap Port: $TRAP_PORT"
info "Docker Mode: $USE_DOCKER"
info "IPv6 Firewall: $USE_IPV6"

# ------------------------------------------------------------------------------
# 5. DEPLOYMENT PLAN PREVIEW
# ------------------------------------------------------------------------------
header "DEPLOYMENT PLAN"

echo -e "${BOLD}The following actions will be performed:${NC}"
echo ""
echo "  ${CYAN}Step 1: Initial Hardening (init_setting.sh)${NC}"
echo "    • Backup critical configurations"
echo "    • Change all user passwords"
echo "    • Kick suspicious users (keeping current admin)"
echo "    • Remove SSH authorized_keys"
echo ""
echo "  ${CYAN}Step 2: Firewall Setup (firewall_safe.sh)${NC}"
echo "    • Configure iptables with whitelist rules"
if [ "$USE_IPV6" == "true" ]; then
    echo "    • Configure ip6tables for IPv6"
fi
echo "    • Set up honeypot trap on port $TRAP_PORT"
echo ""
echo "  ${CYAN}Step 3: Service Cleanup (service_killer.sh)${NC}"
echo "    • Disable potentially dangerous services"
echo "    • Protected services will be preserved"
echo ""
echo "  ${CYAN}Step 4: Monitoring (monitor.sh)${NC}"
echo "    • Launch real-time defense dashboard"
echo ""

if is_dry_run; then
    echo -e "${YELLOW}[DRY-RUN MODE]${NC} No changes will be made."
    echo ""
fi

# Final confirmation
if [ "$INTERACTIVE" == "true" ]; then
    if ! confirm "Proceed with deployment?" "n"; then
        info "Deployment cancelled by user."
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# 6. INSTALL DEPENDENCIES
# ------------------------------------------------------------------------------
header "INSTALLING DEPENDENCIES"

info "Installing essential tools (net-tools, iptables)..."

if ! is_dry_run; then
    case "$PKG_MANAGER" in
        "apt-get")
            apt-get update -y > /dev/null 2>&1
            apt-get install -y net-tools iproute2 iptables > /dev/null 2>&1
            ;;
        "dnf"|"yum")
            $PKG_MANAGER install -y net-tools iproute iptables-services > /dev/null 2>&1
            ;;
        "pacman")
            pacman -Sy --noconfirm net-tools iproute2 iptables > /dev/null 2>&1
            ;;
        "zypper")
            zypper install -y net-tools iproute2 iptables > /dev/null 2>&1
            ;;
    esac
fi

success "Dependencies ready."

# ------------------------------------------------------------------------------
# 7. EXECUTION SEQUENCE
# ------------------------------------------------------------------------------

# Step 1: Initial Hardening
header "STEP 1: INITIAL HARDENING"
if [ -f "./init_setting.sh" ]; then
    if [ "$INTERACTIVE" == "true" ]; then
        if confirm "Run initial hardening (password change, user cleanup)?" "y"; then
            ./init_setting.sh
        else
            warn "Skipping initial hardening."
        fi
    else
        ./init_setting.sh
    fi
else
    error "init_setting.sh not found!"
fi

# Step 2: Firewall
header "STEP 2: FIREWALL SETUP"
if [ -f "./firewall_safe.sh" ]; then
    if [ "$INTERACTIVE" == "true" ]; then
        if confirm "Apply firewall rules?" "y"; then
            ./firewall_safe.sh
        else
            warn "Skipping firewall setup."
        fi
    else
        ./firewall_safe.sh
    fi
else
    error "firewall_safe.sh not found!"
fi

# Step 3: Service Cleanup
header "STEP 3: SERVICE CLEANUP"
if [ -f "./service_killer.sh" ]; then
    if [ "$INTERACTIVE" == "true" ]; then
        if confirm "Disable potentially risky services?" "y"; then
            ./service_killer.sh
        else
            warn "Skipping service cleanup."
        fi
    else
        ./service_killer.sh
    fi
else
    error "service_killer.sh not found!"
fi

# ------------------------------------------------------------------------------
# 8. COMPLETION
# ------------------------------------------------------------------------------
header "DEPLOYMENT COMPLETE"

if is_dry_run; then
    success "Dry-run completed. No changes were made."
    info "Run without --dry-run to apply changes."
else
    success "All defense scripts executed successfully!"
    info "Log file: $LOG_FILE"
fi

echo ""
if [ "$INTERACTIVE" == "true" ]; then
    if confirm "Launch monitoring dashboard?" "y"; then
        if [ -f "./monitor.sh" ]; then
            ./monitor.sh
        fi
    fi
else
    sleep 2
    if [ -f "./monitor.sh" ]; then
        ./monitor.sh
    fi
fi