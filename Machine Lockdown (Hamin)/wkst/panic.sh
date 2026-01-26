#!/bin/bash
# ==============================================================================
# SCRIPT: panic.sh (Emergency Firewall Reset - ufw)
# PURPOSE: Opens ALL firewall rules in emergency situations
# USE CASE: Run this when you lock yourself out or services break.
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Run as ROOT (sudo)." 
   exit 1
fi

echo "--------------------------------------------------------"
echo " [!!!] PANIC BUTTON ACTIVATED [!!!]"
echo " Disabling ufw firewall..."
echo "--------------------------------------------------------"

if ! command -v ufw &> /dev/null; then
    echo "[!] ufw not found, trying nftables fallback..."
    if command -v nft &> /dev/null; then
        nft flush ruleset
        echo "[OK] nftables flushed."
    else
        echo "[!] nftables not found either. Manual intervention required."
    fi
    exit 0
fi

# Disable ufw
ufw disable

echo ""
echo "[OK] Firewall is now DISABLED."
echo "[WARNING] You are currently vulnerable!"
echo "[WARNING] Fix your rules and run: sudo ./firewall_safe.sh"
echo ""
echo "Current status:"
ufw status