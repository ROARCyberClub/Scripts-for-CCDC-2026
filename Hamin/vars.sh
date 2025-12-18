#!/bin/bash
# ==============================================================================
# CCDC CONFIGURATION FILE (vars.sh) - FIXED
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. NETWORK CONFIG
# ------------------------------------------------------------------------------
SCOREBOARD_IPS=("10.x.x.x") 
OVERRIDE_SSH_PORT=""  # Leave empty to auto-detect

# ------------------------------------------------------------------------------
# 2. FIREWALL CONFIG (Ports/Protocols to OPEN)
# ------------------------------------------------------------------------------
# used by: firewall_safe.sh, monitor.sh
# Options: ssh, http, https, dns, mysql, icmp
ALLOWED_PROTOCOLS=("ssh" "http" "icmp")

# ------------------------------------------------------------------------------
# 3. SERVICE PROTECTION (Daemons to KEEP ALIVE)
# ------------------------------------------------------------------------------
# used by: service_killer.sh
# Put the EXACT process/service names here.
PROTECTED_SERVICES=("ssh" "sshd" "apache2" "nginx" "mysqld")

# ------------------------------------------------------------------------------
# 4. ENVIRONMENT
# ------------------------------------------------------------------------------
USE_DOCKER="false"