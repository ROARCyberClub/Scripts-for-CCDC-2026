#!/bin/bash

# Define the config file path (Adjust if using Kea or DNSMasq)
CONFIG_FILE="/etc/dhcp/dhcpd.conf"
BACKUP_DIR="/root/dhcp_backup"
DEFAULTS_FILE="/etc/default/isc-dhcp-server"
TIMESTAMP=$(date +%F-%T)

# 1. Backup the Configuration
if [ -f "$CONFIG_FILE" ]; then
    mkdir -p $BACKUP_DIR
    cp $CONFIG_FILE "$BACKUP_DIR/dhcpd.conf.bak.$(date +%F-%T)"
    echo "Configuration backed up to $BACKUP_DIR"
else
    echo "$CONFIG_FILE not found. Are you using a different DHCP server?"
    exit 1
fi

# 2. Secure File Permissions
chown root:root $CONFIG_FILE
chmod 644 $CONFIG_FILE
echo "File permissions set to 644 (Owner: Root)"

# 3. Enable Logging (if not present)
if grep -q "log-facility" $CONFIG_FILE; then
    echo "Logging appears to be configured."
else
    echo "log-facility local7;" >> $CONFIG_FILE
    echo "Added logging directive to config."
fi
# 4. Disable DDNS Updates
if grep -qi "ddns-update-style" "$CONFIG_FILE"; then
    echo "[+] DDNS update style already set"
else
    sed -i '1s/^/ddns-update-style none;\n/' "$CONFIG_FILE"
    echo "[+] DDNS updates disabled"
fi

# 5. Set Server as Authoritative
if grep -qi "^authoritative;" "$CONFIG_FILE"; then
    echo "[+] Server already authoritative"
else
    sed -i '1s/^/authoritative;\n/' "$CONFIG_FILE"
    echo "[+] Server set as authoritative"
fi

# 6. Prevent Rogue Updates (basic hardening)
if grep -q "ignore client-updates" $CONFIG_FILE; then
    echo "Client updates are already ignored."
else
    # Insert at the top of the file
    sed -i '1s/^/ignore client-updates;\n/' $CONFIG_FILE
    echo "configured to ignore client-updates (prevents some spoofing)."
fi
# 7. Harden Lease Times
grep -qi "default-lease-time" "$CONFIG_FILE" || \
    sed -i '1s/^/default-lease-time 600;\n/' "$CONFIG_FILE"
grep -qi "max-lease-time" "$CONFIG_FILE" || \
    sed -i '1s/^/max-lease-time 7200;\n/' "$CONFIG_FILE"
echo "Lease times hardened"

# 8. Check for unknown clients
echo "CHECKING CONFIG FOR 'allow unknown-clients'"
grep -i "unknown-clients" $CONFIG_FILE
echo "If you see 'allow unknown-clients', change it to 'deny' IF you have a fixed list of MAC addresses."

# 10. Check for Failover Configuration
echo "Checking for DHCP failover:"
grep -i "failover" "$CONFIG_FILE"

# 11. Interface Lockdown Review
if [ -f "$DEFAULTS_FILE" ]; then
    echo "DHCP interface binding:"
    grep -i INTERFACES "$DEFAULTS_FILE"
    echo "Ensure DHCP is bound ONLY to the correct interface."
else
    echo "$DEFAULTS_FILE not found — verify interface binding manually"
fi

# 12. Validate Configuration Before Restart
echo "Validating DHCP configuration..."
dhcpd -t
if [ $? -ne 0 ]; then
    echo "DHCP config validation FAILED. Service NOT restarted."
    exit 1
fi
echo "Configuration validation passed"

# 13. Restart DHCP Service
service isc-dhcp-server restart 2>/dev/null || systemctl restart dhcpd 2>/dev/null
if [ $? -eq 0 ]; then
    echo "DHCP service restarted successfully"
else
    echo "DHCP restart failed"
    exit 1
fi
# 14. Show Recent DHCP Logs
echo "Recent DHCP log entries:"
journalctl -u isc-dhcp-server --no-pager -n 10 2>/dev/null || \
grep dhcp /var/log/syslog | tail -n 10

echo "DHCP hardening complete."
