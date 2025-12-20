#!/bin/bash
# ==============================================================================
# SCRIPT: firewall_safe.sh (Final: Docker Safe + Nmap Trap + English)
# ==============================================================================

# 1. Import Configuration
if [ -f "./vars.sh" ]; then source ./vars.sh; else echo "[ERROR] vars.sh missing"; exit 1; fi
if [[ $EUID -ne 0 ]]; then echo "[ERROR] Run as root"; exit 1; fi

echo "[*] Applying Firewall Rules (Docker Safe Mode: $USE_DOCKER)..."

# ------------------------------------------------------------------------------
# 2. FLUSH RULES (Docker Safety Logic RESTORED)
# ------------------------------------------------------------------------------
if [ "$USE_DOCKER" == "true" ]; then
    echo "[!] Docker environment detected."
    echo "    -> Flushing INPUT chain only."
    echo "    -> Keeping DOCKER-USER and FORWARD chains intact."
    # In Docker mode, flush only INPUT to preserve container networking
    iptables -F INPUT
else
    echo "[*] No Docker detected (Standard Server)."
    echo "    -> Flushing ALL chains and tables."
    iptables -F
    iptables -X
fi

# 3. SET DEFAULT POLICIES
iptables -P INPUT DROP
# In Docker mode, FORWARD needs to be handled carefully (usually managed by Docker)
if [ "$USE_DOCKER" == "true" ]; then
    # Let Docker manage FORWARD chain (Do nothing or ACCEPT)
    : 
else
    iptables -P FORWARD DROP
fi
iptables -P OUTPUT ACCEPT

# ------------------------------------------------------------------------------
# 4. TRUSTED ZONES (ALWAYS ALLOW)
# ------------------------------------------------------------------------------
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# [CRITICAL] Scoreboard Must Be Allowed BEFORE the Trap Check
# This prevents the Scoreboard from being banned even if they scan ports.
for ip in "${SCOREBOARD_IPS[@]}"; do
    echo "[+] Whitelisting Scoreboard: $ip"
    iptables -A INPUT -s "$ip" -j ACCEPT
done

# ------------------------------------------------------------------------------
# 5. ANTI-NMAP BAN CHECK (The Bouncer)
# ------------------------------------------------------------------------------
# If the attacker stepped on the mine previously, DROP them immediately here.
if [ -n "$TRAP_PORT" ]; then
    echo "[!] Activating Anti-Nmap Trap Checks (Ban Time: ${BAN_TIME}s)"
    # Load module if missing
    modprobe xt_recent 2>/dev/null
    # Check 'PORT_SCANNER' list. If found, update timestamp and DROP.
    iptables -A INPUT -m recent --name PORT_SCANNER --update --seconds "$BAN_TIME" -j DROP
fi

# ------------------------------------------------------------------------------
# 6. ALLOWED SERVICES
# ------------------------------------------------------------------------------
# SSH (Port is now calculated in vars.sh)
echo "[+] Allowing SSH on Port: $SSH_PORT"
iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT

# Services from vars.sh
for proto in "${ALLOWED_PROTOCOLS[@]}"; do
    if [[ "$proto" == "http" ]]; then iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    elif [[ "$proto" == "https" ]]; then iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    elif [[ "$proto" == "mysql" ]]; then iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
    elif [[ "$proto" == "dns" ]]; then
        iptables -A INPUT -p udp --dport 53 -j ACCEPT
        iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    elif [[ "$proto" == "icmp" ]]; then iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    fi
done

# ------------------------------------------------------------------------------
# 7. THE TRAP (The Landmine)
# ------------------------------------------------------------------------------
# Any connection not matched above, touching TRAP_PORT, gets added to the Blacklist.
if [ -n "$TRAP_PORT" ]; then
    # Log triggering
    iptables -A INPUT -p tcp --dport "$TRAP_PORT" -m recent --name PORT_SCANNER --set -j LOG --log-prefix "TRAP_TRIGGERED: " --log-level 4
    # Drop packet
    iptables -A INPUT -p tcp --dport "$TRAP_PORT" -j DROP
fi

echo "[OK] Firewall applied successfully."
echo "     -> Docker Mode: $USE_DOCKER"
echo "     -> Trap Port: $TRAP_PORT"