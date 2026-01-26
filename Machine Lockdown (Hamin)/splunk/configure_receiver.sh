#!/bin/bash
# ==============================================================================
# SCRIPT: configure_receiver.sh
# PURPOSE: Configure rsyslog to accept incoming logs (UDP/TCP 514) on Splunk Server
# USAGE: sudo ./configure_receiver.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

require_root

RSYSLOG_CONF="/etc/rsyslog.conf"

header "Configuring Rsyslog Receiver"

if [ ! -f "$RSYSLOG_CONF" ]; then
    error "rsyslog.conf not found at $RSYSLOG_CONF"
    exit 1
fi

info "Backing up rsyslog.conf..."
cp "$RSYSLOG_CONF" "${RSYSLOG_CONF}.bak.$(date +%F_%T)"

# Enable UDP Reception
info "Enabling UDP 514 reception..."
sed -i 's/^#module(load="imudp")/module(load="imudp")/' "$RSYSLOG_CONF"
sed -i 's/^#input(type="imudp" port="514")/input(type="imudp" port="514")/' "$RSYSLOG_CONF"

# Enable TCP Reception (optional but good to have)
info "Enabling TCP 514 reception..."
sed -i 's/^#module(load="imtcp")/module(load="imtcp")/' "$RSYSLOG_CONF"
sed -i 's/^#input(type="imtcp" port="514")/input(type="imtcp" port="514")/' "$RSYSLOG_CONF"

# Legacy format verification (some older rsyslog versions use $ModLoad imudp)
if grep -q "\$ModLoad imudp" "$RSYSLOG_CONF"; then
    sed -i 's/^#$ModLoad imudp/$ModLoad imudp/' "$RSYSLOG_CONF"
    sed -i 's/^#$UDPServerRun 514/$UDPServerRun 514/' "$RSYSLOG_CONF"
    sed -i 's/^#$ModLoad imtcp/$ModLoad imtcp/' "$RSYSLOG_CONF"
    sed -i 's/^#$InputTCPServerRun 514/$InputTCPServerRun 514/' "$RSYSLOG_CONF"
fi

success "Rsyslog configuration updated."

# Restart Rsyslog
info "Restarting rsyslog service..."
if ! is_dry_run; then
    systemctl restart rsyslog
    if systemctl is-active --quiet rsyslog; then
        success "Rsyslog restarted successfully."
    else
        error "Failed to restart rsyslog. Check config."
        exit 1
    fi
else
    info "[DRY-RUN] Would restart rsyslog"
fi

# Verify Port Listening
if ! is_dry_run; then
    info "Verifying port 514..."
    if command_exists netstat; then
        netstat -ulnp | grep 514
    elif command_exists ss; then
        ss -ulnp | grep 514
    fi
fi
