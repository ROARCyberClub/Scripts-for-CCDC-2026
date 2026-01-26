#!/bin/bash
# ==============================================================================
# SCRIPT: panic.sh (Emergency Firewall Reset - firewalld)
# PURPOSE: Opens ALL firewall rules in emergency situations
# USE CASE: Run this when you lock yourself out or services break.
# ==============================================================================

# 1. Root Check
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Run as ROOT (sudo)." 
   exit 1
fi

echo "--------------------------------------------------------"
echo " [!!!] PANIC BUTTON ACTIVATED [!!!]"
echo " Resetting firewalld to ALLOW ALL..."
echo "--------------------------------------------------------"

# 2. Check if firewalld is available
if ! command -v firewall-cmd &> /dev/null; then
    echo "[!] firewall-cmd not found, trying nftables fallback..."
    
    # Fallback to nftables (modern replacement for iptables)
    if command -v nft &> /dev/null; then
        nft flush ruleset
        echo "[OK] nftables flushed."
    else
        echo "[!] nftables not found either. Manual intervention required."
    fi
    exit 0
fi

# 3. Reset firewalld to permissive state
# Option 1: Set zone to trusted (allows everything)
firewall-cmd --set-default-zone=trusted

# Option 2: Add all common services (alternative approach)
# firewall-cmd --permanent --add-service=ssh
# firewall-cmd --permanent --add-port=1-65535/tcp
# firewall-cmd --reload

# 4. Reload to apply
firewall-cmd --reload

# 5. Verify
echo ""
echo "[OK] Firewall is now WIDE OPEN (trusted zone)."
echo "[WARNING] You are currently vulnerable!"
echo "[WARNING] Fix your rules and run: sudo ./firewall_safe.sh"
echo ""
echo "Current zone:"
firewall-cmd --get-default-zone
echo ""
echo "Current rules:"
firewall-cmd --list-all