#!/bin/bash
# ==============================================================================
# 2026 MWCCDC - UNIVERSAL Windows Splunk UF Deployment
# Targets: VM ??
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# 1. COMPETITION VARIABLES
# ------------------------------------------------------------------------------

INDEXER_IP="172.20.242.20"
INDEXER_PORT="9997"

UF_ADMIN_USER="admin"
UF_ADMIN_PASS="Changeme123!" # change 

SPLUNK_HOME="/opt/splunkforwarder"
DOWNLOAD_DIR="/tmp/splunk_uf"
DOWNLOAD_URL="https://download.splunk.com/products/universalforwarder/releases/10.0.2/linux/splunkforwarder-10.0.2-e2d18b4767e9-linux-amd64.tgz"

# Identify the machine for Splunk 

HOSTNAME=$(hostname)

# ------------------------------------------------------------------------------
# 2. HELPER FUNCTIONS
# ------------------------------------------------------------------------------
log()  { echo "[+] $1"; }
warn() { echo "[!] $1"; }

# ------------------------------------------------------------------------------
# 3. INSTALLATION LOGIC
# ------------------------------------------------------------------------------
if [ ! -x "$SPLUNK_HOME/bin/splunk" ]; then
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"

    log "Downloading Splunk UF for $HOSTNAME..."
    curl -s -O "$DOWNLOAD_URL"

    log "Installing Splunk Universal Forwarder..."
    tar -xzf splunkforwarder-*.tgz -C /opt

    "$SPLUNK_HOME/bin/splunk" start --accept-license --answer-yes \
        --seed-passwd "$UF_ADMIN_PASS"

    "$SPLUNK_HOME/bin/splunk" enable boot-start
else
    warn "Splunk UF already installed on $HOSTNAME."
fi

# ------------------------------------------------------------------------------
# 4. DYNAMIC LOG DISCOVERY (The "Universal" Part)
# ------------------------------------------------------------------------------

LOCAL_CONF="$SPLUNK_HOME/etc/system/local"
mkdir -p "$LOCAL_CONF"

INPUTS_CONF="$LOCAL_CONF/inputs.conf"

# Base configuration for EVERY Linux machine
cat > "$INPUTS_CONF" <<EOF
[default]
host = $HOSTNAME

[monitor:///var/log/syslog]
index = main
disabled = false

[monitor:///var/log/auth.log]
index = main
disabled = false
EOF

# --- AUTO-DETECTION LOGIC ---

# 1. Detect Apache / Nginx (Web Servers)
if systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
    log "Detected Web Server - Adding Web Log Monitors..."
    cat >> "$INPUTS_CONF" <<EOF

[monitor:///var/log/apache2/*.log]
index = main
sourcetype = apache
disabled = false
EOF
fi

# 2. Detect SSH / Secure Logs (RHEL-based)
if [ -f /var/log/secure ]; then
    log "Detected secure log - Adding SSH/Sudo Monitor..."
    cat >> "$INPUTS_CONF" <<EOF

[monitor:///var/log/secure]
index = main
sourcetype = linux_secure
disabled = false
EOF
fi

# 3. Detect Auditd
if systemctl is-active --quiet auditd; then
    log "Detected auditd - Adding Audit Logs..."
    cat >> "$INPUTS_CONF" <<EOF

[monitor:///var/log/audit/audit.log]
index = main
sourcetype = linux_audit
disabled = false
EOF
fi

# ------------------------------------------------------------------------------
# 5. APPLY CONFIG & RESTART
# ------------------------------------------------------------------------------

log "Applying outputs configuration..."

cat > "$LOCAL_CONF/outputs.conf" <<EOF
[tcpout]
defaultGroup = primary_indexers

[tcpout:primary_indexers]
server = ${INDEXER_IP}:${INDEXER_PORT}
EOF

log "Restarting SplunkForwarder..."
"$SPLUNK_HOME/bin/splunk" restart

# Cleanup
rm -rf "$DOWNLOAD_DIR"

log "DONE. $HOSTNAME is now shipping logs to the Splunk indexer."