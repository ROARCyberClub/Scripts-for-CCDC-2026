#!/bin/bash
# ==============================================================================
# CCDC CONFIGURATION FILE - WORKSTATION (Ubuntu 24)
# PURPOSE: General workstation hardening (no specific services)
# FIREWALL: Uses ufw (Ubuntu native)
# USAGE: ./deploy.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. EXECUTION MODE
# ------------------------------------------------------------------------------
INTERACTIVE="true"
DRY_RUN="false"
VERBOSE="true"

# ------------------------------------------------------------------------------
# 2. NETWORK & SSH CONFIGURATION
# ------------------------------------------------------------------------------
SCOREBOARD_IPS=("10.0.0.1")

# Topology IPs (CCDC 2026)
SPLUNK_SERVER_IP="172.20.242.20"
GATEWAY_IP="172.20.242.254"     # Palo Alto Inside
AD_DNS_IP="172.20.240.102"      # AD/DNS


SSH_PORT=22
if [ -n "$OVERRIDE_SSH_PORT" ]; then
    SSH_PORT=$OVERRIDE_SSH_PORT
else
    DETECTED=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | head -n 1 | awk '{print $2}')
    if [ -n "$DETECTED" ]; then
        SSH_PORT=$DETECTED
    fi
fi

# ------------------------------------------------------------------------------
# 3. ALLOWED PROTOCOLS / PORTS (Workstation - minimal)
# ------------------------------------------------------------------------------
# Workstation needs minimal ports - just SSH and ping
ALLOWED_PROTOCOLS=(
    "ssh"       # Remote management
    "icmp"      # Ping for scoring
)

# ------------------------------------------------------------------------------
# 4. PROTECTED SERVICES (Whitelist)
# ------------------------------------------------------------------------------
# Workstation - protect SSH only
PROTECTED_SERVICES=(
    "ssh" "sshd"
)

# ------------------------------------------------------------------------------
# 5. PROTECTED USERS (Whitelist)
# ------------------------------------------------------------------------------
PROTECTED_USERS=(
    "root"
    # Add competition-specific usernames here
)

# ------------------------------------------------------------------------------
# 6. ENVIRONMENT
# ------------------------------------------------------------------------------
USE_DOCKER="false"
USE_IPV6="true"

# Firewall type: ufw for Ubuntu 24
FIREWALL_TYPE="ufw"

# ------------------------------------------------------------------------------
# 7. SECURITY TRAPS (Honeypot)
# ------------------------------------------------------------------------------
TRAP_PORT="1337"
BAN_TIME="120"

# ------------------------------------------------------------------------------
# 8. LOGGING
# ------------------------------------------------------------------------------
LOG_DIR="/var/log/ccdc"

# ------------------------------------------------------------------------------
# 9. FIREWALL SAFETY
# ------------------------------------------------------------------------------
FIREWALL_ROLLBACK_TIMEOUT=60

# ------------------------------------------------------------------------------
# 10. AUDIT SETTINGS
# ------------------------------------------------------------------------------
AUDIT_CRON_PATHS=(
    "/etc/crontab"
    "/etc/cron.d"
    "/etc/cron.daily"
    "/etc/cron.hourly"
    "/var/spool/cron"
)

KNOWN_SUID_BINARIES=(
    "/usr/bin/sudo"
    "/usr/bin/passwd"
    "/usr/bin/su"
    "/usr/bin/mount"
    "/usr/bin/umount"
    "/usr/bin/ping"
    "/usr/bin/chsh"
    "/usr/bin/chfn"
    "/usr/bin/newgrp"
    "/usr/bin/gpasswd"
)
