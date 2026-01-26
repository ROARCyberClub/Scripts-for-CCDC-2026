#!/bin/bash
# ==============================================================================
# CCDC CONFIGURATION FILE - WEBMAIL SERVER (Fedora 42)
# PURPOSE: Mail server configuration (Postfix/Dovecot)
# FIREWALL: Uses firewalld (Fedora native)
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
SCOREBOARD_IPS=("10.0.0.1")

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
# 3. ALLOWED PROTOCOLS / PORTS (Webmail-specific)
# ------------------------------------------------------------------------------
# Mail server needs: SMTP, IMAP, POP3, HTTP(S) for webmail interface
ALLOWED_PROTOCOLS=(
    "ssh"       # Remote management
    "http"      # Webmail interface (Roundcube, etc.)
    "https"     # Secure webmail
    "smtp"      # Outgoing mail (port 25)
    "imap"      # Mail retrieval (port 143)
    "pop3"      # Mail retrieval (port 110)
    "icmp"      # Ping for scoring
)

# Additional ports for secure mail (add to firewall_safe.sh if needed)
# - SMTPS: 465 (secure SMTP)
# - SUBMISSION: 587 (mail submission)
# - IMAPS: 993 (secure IMAP)
# - POP3S: 995 (secure POP3)

# ------------------------------------------------------------------------------
# 4. PROTECTED SERVICES (Whitelist)
# ------------------------------------------------------------------------------
# Mail server services - DO NOT DISABLE
PROTECTED_SERVICES=(
    # SSH (always protect)
    "ssh" "sshd"
    
    # Mail Transfer Agent
    "postfix"
    "sendmail"      # If used instead
    
    # Mail Delivery Agent
    "dovecot"
    
    # Web interface (for webmail)
    "apache2" "httpd"
    "nginx"
    "php-fpm"
    
    # Database (for webmail users)
    "mysqld" "mysql" "mariadb"
    "postgresql"
)

# ------------------------------------------------------------------------------
# 5. PROTECTED USERS (Whitelist)
# ------------------------------------------------------------------------------
PROTECTED_USERS=(
    "root"
    "postfix"       # Postfix mail user
    "dovecot"       # Dovecot user
    "mail"          # General mail user
    "www-data"      # Web server user
    "apache"        # Apache on Fedora
    "nginx"         # Nginx user
    # Add competition-specific usernames here
)

# ------------------------------------------------------------------------------
# 6. ENVIRONMENT
# ------------------------------------------------------------------------------
USE_DOCKER="false"
USE_IPV6="true"

# Firewall type: firewalld for Fedora 42 (NOT iptables)
FIREWALL_TYPE="firewalld"

# ------------------------------------------------------------------------------
# 6.5. MAIL SERVER PORTS (for firewall)
# ------------------------------------------------------------------------------
# Standard mail ports
MAIL_SMTP_PORT="25"
MAIL_IMAP_PORT="143"
MAIL_POP3_PORT="110"

# Secure mail ports (optional, add if needed)
MAIL_SMTPS_PORT="465"
MAIL_SUBMISSION_PORT="587"
MAIL_IMAPS_PORT="993"
MAIL_POP3S_PORT="995"

# ------------------------------------------------------------------------------
# 7. SECURITY TRAPS (Honeypot)
# ------------------------------------------------------------------------------
TRAP_PORT="2222"    # Fake SSH port
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
