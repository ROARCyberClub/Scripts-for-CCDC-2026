#!/bin/bash
# ==============================================================================
# CCDC CONFIGURATION FILE (vars.sh)
# ==============================================================================

# 1. NETWORK
SCOREBOARD_IPS=("10.x.x.x") 
OVERRIDE_SSH_PORT=""

# 2. ALLOWED PORTS
ALLOWED_PROTOCOLS=("ssh" "http" "icmp")

# 3. PROTECTED SERVICES (WhiteList)
# We list BOTH Debian and RHEL service names to be safe on ANY OS.
PROTECTED_SERVICES=(
    "ssh" "sshd"
    "apache2" "httpd"        # Web Server (Debian / RHEL)
    "nginx"
    "mysqld" "mysql" "mariadb" # Database (Various names)
    "postgresql" "pgsql"
)

# 4. ENV
USE_DOCKER="false"