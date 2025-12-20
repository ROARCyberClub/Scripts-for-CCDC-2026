#!/bin/bash
# ==============================================================================
# SCRIPT: deploy.sh (AUTO-DETECT OS VERSION)
# ==============================================================================

if [[ $EUID -ne 0 ]]; then echo "[ERROR] Run as ROOT."; exit 1; fi

# ------------------------------------------------------------------------------
# 1. OS DETECTION & PREPARATION
# ------------------------------------------------------------------------------
echo "[*] DETECTING SYSTEM ENVIRONMENT..."

# Detect Package Manager
PKG_MANAGER=""
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
    echo "    -> Detected: Debian/Ubuntu based (apt-get)"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    echo "    -> Detected: RHEL/CentOS/Rocky (dnf)"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    echo "    -> Detected: RHEL/CentOS Legacy (yum)"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    echo "    -> Detected: Arch Linux (pacman)"
elif command -v zypper &> /dev/null; then
    PKG_MANAGER="zypper"
    echo "    -> Detected: SUSE/OpenSUSE (zypper)"
else
    echo "    -> [WARNING] Unknown OS. Manual installation might be needed."
fi

# Sanitization
sed -i 's/\r$//' *.sh
chmod +x *.sh

# Config Check
if [ ! -f "./vars.sh" ]; then echo "[ERROR] vars.sh missing."; exit 1; fi
source ./vars.sh

# Scoreboard IP Check
if [[ "${SCOREBOARD_IPS[0]}" == "10.x.x.x" ]]; then
    echo "[STOP] Edit vars.sh -> Set SCOREBOARD_IPS first!"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. INSTALL DEPENDENCIES (OS AGNOSTIC)
# ------------------------------------------------------------------------------
echo "[*] Installing essential tools (net-tools, iptables)..."

case "$PKG_MANAGER" in
    "apt-get")
        apt-get update -y > /dev/null
        apt-get install -y net-tools iproute2 iptables > /dev/null
        ;;
    "dnf"|"yum")
        $PKG_MANAGER install -y net-tools iproute iptables-services > /dev/null
        ;;
    "pacman")
        pacman -Sy --noconfirm net-tools iproute2 iptables > /dev/null
        ;;
    "zypper")
        zypper install -y net-tools iproute2 iptables > /dev/null
        ;;
esac

# ------------------------------------------------------------------------------
# 3. EXECUTION SEQUENCE
# ------------------------------------------------------------------------------
# [init_setting.sh]
if [ -f "./init_setting.sh" ]; then
    echo "[*] Running Initial Hardening..."
    ./init_setting.sh
else
    echo "[CRITICAL] init_setting.sh NOT FOUND."
fi

# [firewall_safe.sh]
if [ -f "./firewall_safe.sh" ]; then
    ./firewall_safe.sh
fi

# [service_killer.sh]
if [ -f "./service_killer.sh" ]; then
    ./service_killer.sh
fi

echo "[*] Deployment Complete. Launching Monitor..."
sleep 2
if [ -f "./monitor.sh" ]; then ./monitor.sh; fi