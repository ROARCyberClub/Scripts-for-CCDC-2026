#!/bin/bash
# ==============================================================================
# CCDC CONFIGURATION FILE - SPLUNK SERVER (Oracle Linux 9)
# PURPOSE: Log analysis and SIEM server configuration
# FIREWALL: Uses firewalld (Oracle Linux 9 native)
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
# IMPORTANT: Update this with actual scoreboard IPs before competition!
# Scoreboard IP is usually in the external range (e.g., 10.x.x.x or 172.25.x.x)
SCOREBOARD_IPS=("10.0.0.1")

# Topology IPs (CCDC 2026)
SPLUNK_SERVER_IP="172.20.242.20"
GATEWAY_IP="172.20.242.254"     # Palo Alto Inside
AD_DNS_IP="172.20.240.102"      # AD/DNS


# SSH Port
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
# 3. ALLOWED PROTOCOLS / PORTS (Splunk-specific)
# ------------------------------------------------------------------------------
# Splunk needs: Web UI (8000), Forwarder (9997), Management (8089)
ALLOWED_PROTOCOLS=(
    "ssh"       # Remote management
    "http"      # If reverse proxy used
    "https"     # Secure access
    "icmp"      # Ping for scoring
)

# Splunk-specific ports (will be added manually in firewall_safe.sh)
# These are not standard protocols, need custom rules
SPLUNK_WEB_PORT="8000"          # Splunk Web UI
SPLUNK_FORWARDER_PORT="9997"    # Data receiving from forwarders
SPLUNK_MGMT_PORT="8089"         # Management API
SPLUNK_KV_PORT="8191"           # KV Store (if used)
SPLUNK_SYSLOG_PORT="514"        # Syslog Reception (UDP/TCP)

# ------------------------------------------------------------------------------
# 4. PROTECTED SERVICES (Whitelist)
# ------------------------------------------------------------------------------
# Splunk services - DO NOT DISABLE
PROTECTED_SERVICES=(
    # SSH (always protect)
    "ssh" "sshd"
    
    # Splunk services
    "splunk"
    "splunkd"
    "Splunkd"
    
    # Splunk runs as its own service, protect it
    "splunk.service"
)

# ------------------------------------------------------------------------------
# 5. PROTECTED USERS (Whitelist)
# ------------------------------------------------------------------------------
PROTECTED_USERS=(
    "root"
    "splunk"        # Splunk service user
    # Add competition-specific usernames here
)

# ------------------------------------------------------------------------------
# 6. ENVIRONMENT
# ------------------------------------------------------------------------------
USE_DOCKER="false"
USE_IPV6="true"

# Firewall type: firewalld for Oracle Linux 9 (NOT iptables)
FIREWALL_TYPE="firewalld"

# ------------------------------------------------------------------------------
# 6.5. SPLUNK CONFIGURATION
# ------------------------------------------------------------------------------
SPLUNK_HOME="${SPLUNK_HOME:-/opt/splunk}"

# ------------------------------------------------------------------------------
# 7. SECURITY TRAPS (Honeypot)
# ------------------------------------------------------------------------------
TRAP_PORT="23"      # Fake Telnet port
BAN_TIME="120"      # Ban for 2 minutes

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

# ==============================================================================
# NOTE: Splunk ports are automatically added by firewall_safe.sh
# Ports: 8000 (Web), 8089 (API), 9997 (Forwarders)
# ==============================================================================
