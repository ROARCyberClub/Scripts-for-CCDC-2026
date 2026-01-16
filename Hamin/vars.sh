#!/bin/bash
# ==============================================================================
# CCDC CONFIGURATION FILE (vars.sh)
# PURPOSE: Central configuration for all CCDC defense scripts
# USAGE: Sourced by other scripts. Edit values below before running deploy.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. EXECUTION MODE
# ------------------------------------------------------------------------------
# Interactive mode: prompts for confirmation before dangerous actions
INTERACTIVE="true"

# Dry-run mode: shows what would happen without making changes
DRY_RUN="true"

# Verbose mode: show detailed logging output
VERBOSE="true"

# ------------------------------------------------------------------------------
# 2. NETWORK & SSH CONFIGURATION
# ------------------------------------------------------------------------------
# IMPORTANT: Update this with actual scoreboard IPs before competition!
SCOREBOARD_IPS=("10.0.0.1")

# SSH Port: Auto-detected from sshd_config, or set manually here
# To override auto-detection, uncomment and set:
# OVERRIDE_SSH_PORT=2222

# [LOGIC: DETERMINE FINAL SSH PORT]
SSH_PORT=22 # Default fallback
if [ -n "$OVERRIDE_SSH_PORT" ]; then
    SSH_PORT=$OVERRIDE_SSH_PORT
else
    # Auto-detect from sshd_config (ignores commented lines)
    DETECTED=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | head -n 1 | awk '{print $2}')
    if [ -n "$DETECTED" ]; then
        SSH_PORT=$DETECTED
    fi
fi

# ------------------------------------------------------------------------------
# 3. ALLOWED PROTOCOLS / PORTS
# ------------------------------------------------------------------------------
# Services that should be accessible from the network
# Supported: ssh, http, https, dns, mysql, postgresql, pgsql, ftp, 
#            smtp, pop3, imap, smb, samba, icmp
ALLOWED_PROTOCOLS=("ssh" "http" "icmp")

# ------------------------------------------------------------------------------
# 4. PROTECTED SERVICES (Whitelist)
# ------------------------------------------------------------------------------
# These services will NOT be stopped by service_killer.sh
# List BOTH Debian and RHEL names to be safe on any OS
PROTECTED_SERVICES=(
    # SSH (always protect)
    "ssh" "sshd"
    
    # Web Servers
    "apache2" "httpd"
    "nginx"
    
    # Databases
    "mysqld" "mysql" "mariadb"
    "postgresql" "pgsql"
)

# ------------------------------------------------------------------------------
# 5. PROTECTED USERS (Whitelist)
# ------------------------------------------------------------------------------
# These users will NOT be kicked by init_setting.sh
# The current admin user is automatically protected
PROTECTED_USERS=(
    "root"
    # Add competition-specific usernames here, e.g.:
    # "sysadmin"
    # "webadmin"
)

# ------------------------------------------------------------------------------
# 6. ENVIRONMENT
# ------------------------------------------------------------------------------
# Set to "true" if running in Docker environment
# This prevents flushing FORWARD chain which breaks Docker networking
USE_DOCKER="false"

# Enable IPv6 firewall rules
USE_IPV6="true"

# ------------------------------------------------------------------------------
# 7. SECURITY TRAPS (Honeypot)
# ------------------------------------------------------------------------------
# If an attacker touches TRAP_PORT, the system will block the IP
TRAP_PORT="1025"
BAN_TIME="60"  # Blocking time in seconds

# ------------------------------------------------------------------------------
# 8. LOGGING
# ------------------------------------------------------------------------------
LOG_DIR="/var/log/ccdc"

# ------------------------------------------------------------------------------
# 9. FIREWALL SAFETY
# ------------------------------------------------------------------------------
# Auto-rollback timeout (seconds) - if you can't confirm new rules, 
# firewall will revert to previous state
FIREWALL_ROLLBACK_TIMEOUT=60

# ------------------------------------------------------------------------------
# 10. AUDIT SETTINGS
# ------------------------------------------------------------------------------
# Paths to check for backdoors
AUDIT_CRON_PATHS=(
    "/etc/crontab"
    "/etc/cron.d"
    "/etc/cron.daily"
    "/etc/cron.hourly"
    "/var/spool/cron"
)

# Known good SUID binaries (skip these in audit)
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