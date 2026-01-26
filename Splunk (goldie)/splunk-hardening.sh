#!/bin/bash
# ==============================================================================
# MWCCDC - SPLUNK SERVER HARDENING SCRIPT
# Works on Windows (Git Bash / WSL / PowerShell wrapper) and Linux
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# 1. CONFIGURATION
# ------------------------------------------------------------------------------

NEW_ADMIN_PASS="" # add password
NEW_SYSADMIN_PASS="" # add password

NEW_WEB_PORT="8443"
NEW_MGMT_PORT="8090"

SPLUNK_HOME="/opt/splunk"
SPLUNK_BIN="$SPLUNK_HOME/bin/splunk"

# ------------------------------------------------------------------------------
# 2. HELPER FUNCTIONS
# ------------------------------------------------------------------------------

log()  { echo "[+] $(date +%H:%M:%S) $1"; }
warn() { echo "[!] $(date +%H:%M:%S) $1"; }

# ------------------------------------------------------------------------------
# 3. SANITY CHECK
# ------------------------------------------------------------------------------

if [ ! -x "$SPLUNK_BIN" ]; then
    warn "Splunk binary not found at $SPLUNK_BIN"
    exit 1
fi

log "Splunk detected at $SPLUNK_HOME"

# ------------------------------------------------------------------------------
# 4. CHANGE SPLUNK ADMIN PASSWORD
# ------------------------------------------------------------------------------

log "Changing Splunk admin password..."
"$SPLUNK_BIN" edit user admin \
    -password "$NEW_ADMIN_PASS" \
    -role admin \
    -auth admin:changeme 2>/dev/null || \
"$SPLUNK_BIN" edit user admin \
    -password "$NEW_ADMIN_PASS" \
    -role admin \
    -auth admin:"$NEW_ADMIN_PASS"

# ------------------------------------------------------------------------------
# 5. CHANGE SPLUNK SYSADMIN PASSWORD (IF IT EXISTS)
# ------------------------------------------------------------------------------

log "Checking for Splunk user 'sysadmin'..."

if "$SPLUNK_BIN" list user -auth admin:"$NEW_ADMIN_PASS" | grep -q "^sysadmin"; then
    warn "Splunk user 'sysadmin' FOUND — changing password!"
    "$SPLUNK_BIN" edit user sysadmin \
        -password "$NEW_SYSADMIN_PASS" \
        -auth admin:"$NEW_ADMIN_PASS"
else
    log "No Splunk user named 'sysadmin' found (good)."
fi

# ------------------------------------------------------------------------------
# 6. ENUMERATE ALL SPLUNK USERS
# ------------------------------------------------------------------------------

log "Enumerating all Splunk users:"
"$SPLUNK_BIN" list user -auth admin:"$NEW_ADMIN_PASS"

warn "Review the above list for unexpected users or extra admins."

# ------------------------------------------------------------------------------
# 7. CHANGE DEFAULT PORTS
# ------------------------------------------------------------------------------

log "Changing Splunk Web and Management ports..."

cat > "$SPLUNK_HOME/etc/system/local/web.conf" <<EOF
[settings]
httpport = $NEW_WEB_PORT
enableSplunkWebSSL = true
EOF

cat > "$SPLUNK_HOME/etc/system/local/server.conf" <<EOF
[httpServer]
port = $NEW_MGMT_PORT

[tcpip]
listenOnIPv6 = no
EOF

# ------------------------------------------------------------------------------
# 8. RESTART SPLUNK
# ------------------------------------------------------------------------------

log "Restarting Splunk..."
"$SPLUNK_BIN" restart

# ------------------------------------------------------------------------------
# 9. VERIFY LISTENING PORTS
# ------------------------------------------------------------------------------

log "Verifying Splunk listeners..."
ss -tulnp | grep splunk || warn "Could not confirm Splunk listeners"

log "DONE. Splunk users and ports hardened."