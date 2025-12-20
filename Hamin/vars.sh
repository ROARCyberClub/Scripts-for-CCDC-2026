#!/bin/bash
# ==============================================================================
# CCDC CONFIGURATION FILE (vars.sh)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. NETWORK & SSH CONFIGURATION
# ------------------------------------------------------------------------------
SCOREBOARD_IPS=("10.x.x.x") 

# [LOGIC: DETERMINE FINAL SSH PORT]
# This variable ($SSH_PORT) will be used by firewall_safe.sh
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
# 2. ALLOWED PORTS
# ------------------------------------------------------------------------------
ALLOWED_PROTOCOLS=("ssh" "http" "icmp")

# ------------------------------------------------------------------------------
# 3. PROTECTED SERVICES (WhiteList)
# ------------------------------------------------------------------------------
# We list BOTH Debian and RHEL service names to be safe on ANY OS.
PROTECTED_SERVICES=(
    "ssh" "sshd"
    "apache2" "httpd"        # Web Server (Debian / RHEL)
    "nginx"
    "mysqld" "mysql" "mariadb" # Database (Various names)
    "postgresql" "pgsql"
)

# ------------------------------------------------------------------------------
# 4. ENVIRONMENT
# ------------------------------------------------------------------------------
USE_DOCKER="false"

# ------------------------------------------------------------------------------
# 5. SECURITY TRAPS (Landmine)
# ------------------------------------------------------------------------------
# If an attacker touches TRAP_PORT, the system will block the IP for BAN_TIME
TRAP_PORT="55555"
BAN_TIME="60" # Blocking Time (seconds)