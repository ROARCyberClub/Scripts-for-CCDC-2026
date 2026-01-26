#!/bin/bash
# ==============================================================================
# SCRIPT: panic.sh (Emergency Firewall Reset - firewalld)
# PURPOSE: Opens ALL firewall rules in emergency situations
# USE CASE: Run this when you lock yourself out or services break.
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Run as ROOT (sudo)." 
   exit 1
fi

echo "--------------------------------------------------------"
echo " [!!!] PANIC BUTTON ACTIVATED [!!!]"
echo " Resetting firewalld to ALLOW ALL..."
echo "--------------------------------------------------------"

if ! command -v firewall-cmd &> /dev/null; then
    echo "[!] firewall-cmd not found, trying iptables fallback..."
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
    iptables -X
    echo "[OK] iptables flushed."
    exit 0
fi

firewall-cmd --set-default-zone=trusted
firewall-cmd --reload

echo ""
echo "[OK] Firewall is now WIDE OPEN (trusted zone)."
echo "[WARNING] You are currently vulnerable!"
echo "[WARNING] Fix your rules and run: sudo ./firewall_safe.sh"
echo ""
echo "Current zone:"
firewall-cmd --get-default-zone