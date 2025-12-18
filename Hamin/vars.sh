#!/bin/bash
# ==============================================================================
# CCDC CONFIGURATION FILE (vars.sh) - EXPERT V2
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. NETWORK CONFIG
# ------------------------------------------------------------------------------
SCOREBOARD_IPS=("10.x.x.x") 
OVERRIDE_SSH_PORT=""  # Leave empty to auto-detect

# ------------------------------------------------------------------------------
# 2. FIREWALL CONFIG (Ports/Protocols to OPEN)
# ------------------------------------------------------------------------------
# firewall_safe.sh will look at THIS list.
# Options: ssh, http, https, dns, mysql, icmp
ALLOWED_PROTOCOLS=("ssh" "http" "icmp")

# ------------------------------------------------------------------------------
# 3. SERVICE PROTECTION (Daemons to KEEP ALIVE)
# ------------------------------------------------------------------------------
# service_killer.sh will look at THIS list.
# Put the EXACT process/service names here.
# Tip: Use 'systemctl list-units --type=service' to find names.
PROTECTED_SERVICES=("ssh" "sshd" "apache2" "nginx" "mysqld")

# ------------------------------------------------------------------------------
# 4. ENVIRONMENT
# ------------------------------------------------------------------------------
USE_DOCKER="false"