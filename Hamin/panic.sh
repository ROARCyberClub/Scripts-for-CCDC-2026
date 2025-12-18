#!/bin/bash
# ==============================================================================
# SCRIPT: panic.sh (The Emergency Exit)
# PURPOSE: Flushes ALL firewall rules and ALLOWS everything.
# USE CASE: Run this when you lock yourself out or services break.
# ==============================================================================

# 1. Root Check
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Run as ROOT (sudo)." 
   exit 1
fi

echo "--------------------------------------------------------"
echo " [!!!] PANIC BUTTON ACTIVATED [!!!]"
echo " Flushing ALL Firewall Rules... Opening ALL Ports..."
echo "--------------------------------------------------------"

# 2. Reset Default Policies to ACCEPT (Allow Everything)
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# 3. Flush All Rules (Delete All Restrictions)
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# 4. Verify
echo "[OK] Firewall is now WIDE OPEN."
echo "[WARNING] You are currently vulnerable. Fix your rules and re-apply."
iptables -L -n | head -n 5