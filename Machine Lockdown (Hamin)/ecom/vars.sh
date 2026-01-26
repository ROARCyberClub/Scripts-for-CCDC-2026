#!/bin/bash
# ==============================================================================
# CCDC CONFIGURATION FILE - ECOM SERVER (Ubuntu 24)
# PURPOSE: E-commerce web server configuration (Apache/Nginx, MySQL)
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
# 3. ALLOWED PROTOCOLS / PORTS (Ecom-specific)
# ------------------------------------------------------------------------------
# E-commerce needs: HTTP, HTTPS, MySQL (if database is local)
ALLOWED_PROTOCOLS=(
    "ssh"       # Remote management
    "http"      # Web traffic (port 80)
    "https"     # Secure web traffic (port 443)
    "mysql"     # Database (port 3306) - if MySQL is on this server
    "icmp"      # Ping for scoring
)

# ------------------------------------------------------------------------------
# 4. PROTECTED SERVICES (Whitelist)
# ------------------------------------------------------------------------------
# E-commerce server services - DO NOT DISABLE
PROTECTED_SERVICES=(
    # SSH (always protect)
    "ssh" "sshd"
    
    # Web Servers (E-commerce)
    "apache2" "httpd"
    "nginx"
    
    # PHP (if used)
    "php-fpm" "php8.1-fpm" "php8.2-fpm"
    
    # Databases (if local)
    "mysqld" "mysql" "mariadb"
)

# ------------------------------------------------------------------------------
# 5. PROTECTED USERS (Whitelist)
# ------------------------------------------------------------------------------
PROTECTED_USERS=(
    "root"
    "www-data"      # Apache/Nginx user
    "mysql"         # MySQL user
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
TRAP_PORT="1337"    # Fake SSH port to catch scanners
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
