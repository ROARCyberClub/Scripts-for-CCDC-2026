#!/bin/bash
# ==============================================================================
# SCRIPT: firewall_safe.sh
# PURPOSE: Applies iptables rules SAFELY using vars.sh
# ==============================================================================

# 1. Import Configuration
if [ -f "./vars.sh" ]; then
    source ./vars.sh
else
    echo "[ERROR] vars.sh not found! Cannot proceed safely."
    exit 1
fi

# 2. Root Check
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] This script must be run as root." 
   exit 1
fi

echo "[*] Applying SAFE Firewall Rules..."

# 3. Docker Safety Check
if [ "$USE_DOCKER" == "true" ]; then
    echo "[!] Docker environment detected. NOT flushing all rules."
    # Only flush INPUT chain to preserve Docker chains
    iptables -F INPUT
else
    echo "[*] No Docker detected. Flushing all rules."
    iptables -F
    iptables -X
fi

# 4. Default Policies (Fail Safe)
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# 5. TRUSTED RULES (Priority 1)
# ------------------------------------------------------------------------------
# Allow Loopback (Localhost) - Vital for system stability
iptables -A INPUT -i lo -j ACCEPT

# Allow Established Connections - Don't kick yourself out!
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow Scoreboard (Whitelisting)
for ip in "${SCOREBOARD_IPS[@]}"; do
    echo "[+] Whitelisting Scoreboard IP: $ip"
    iptables -A INPUT -s "$ip" -j ACCEPT
done

# 6. SSH ACCESS (Priority 2)
# ------------------------------------------------------------------------------
# Determine SSH Port
REAL_SSH_PORT=22
if [ -n "$OVERRIDE_SSH_PORT" ]; then
    REAL_SSH_PORT=$OVERRIDE_SSH_PORT
else
    # Attempt Auto-detect
    DETECTED_PORT=$(grep "^Port" /etc/ssh/sshd_config | head -n 1 | awk '{print $2}')
    if [ -n "$DETECTED_PORT" ]; then
        REAL_SSH_PORT=$DETECTED_PORT
    fi
fi

echo "[+] Allowing SSH on Port: $REAL_SSH_PORT"
iptables -A INPUT -p tcp --dport "$REAL_SSH_PORT" -j ACCEPT

# 7. SCORED SERVICES (Priority 3)
# ------------------------------------------------------------------------------
# Add rules for HTTP/HTTPS/DNS if they are in SCORED_SERVICES
for proto in "${ALLOWED_PROTOCOLS[@]}"; do
    if [[ "$proto" == "http" ]]; then
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    elif [[ "$proto" == "https" ]]; then
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    elif [[ "$proto" == "mysql" ]]; then
        iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
    elif [[ "$svc" == "dns" ]]; then
        iptables -A INPUT -p udp --dport 53 -j ACCEPT
        iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    elif [[ "$svc" == "icmp" ]]; then
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    fi
done

echo "[OK] Safe firewall applied. Check 'iptables -L -n' to verify."