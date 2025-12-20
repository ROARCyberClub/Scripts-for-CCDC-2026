#!/bin/bash
# ==============================================================================
# SCRIPT: firewall_safe.sh (Final: Universal Protocol Support)
# ==============================================================================

# 1. Import Configuration
if [ -f "./vars.sh" ]; then source ./vars.sh; else echo "[ERROR] vars.sh missing"; exit 1; fi
if [[ $EUID -ne 0 ]]; then echo "[ERROR] Run as root"; exit 1; fi

echo "[*] Applying Firewall Rules (Docker Safe Mode: $USE_DOCKER)..."

# ------------------------------------------------------------------------------
# 2. FLUSH RULES
# ------------------------------------------------------------------------------
if [ "$USE_DOCKER" == "true" ]; then
    echo "[!] Docker environment detected. Flushing INPUT only."
    iptables -F INPUT
else
    echo "[*] No Docker detected. Flushing ALL."
    iptables -F; iptables -X
fi

# 3. SET DEFAULT POLICIES
iptables -P INPUT DROP
if [ "$USE_DOCKER" == "true" ]; then :; else iptables -P FORWARD DROP; fi
iptables -P OUTPUT ACCEPT

# 4. TRUSTED ZONES
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ------------------------------------------------------------------------------
# 5. SCOREBOARD ACCESS (Restricted Whitelist)
# ------------------------------------------------------------------------------
# Helper function to open ports based on protocol names
allow_protocol_for_ip() {
    local ip="$1"
    local proto="$2"
    
    case "$proto" in
        "http")     iptables -A INPUT -s "$ip" -p tcp --dport 80 -j ACCEPT ;;
        "https")    iptables -A INPUT -s "$ip" -p tcp --dport 443 -j ACCEPT ;;
        "dns")      iptables -A INPUT -s "$ip" -p udp --dport 53 -j ACCEPT
                    iptables -A INPUT -s "$ip" -p tcp --dport 53 -j ACCEPT ;;
        "mysql")    iptables -A INPUT -s "$ip" -p tcp --dport 3306 -j ACCEPT ;;
        "postgresql"|"pgsql") iptables -A INPUT -s "$ip" -p tcp --dport 5432 -j ACCEPT ;;
        "ftp")      iptables -A INPUT -s "$ip" -p tcp --dport 21 -j ACCEPT ;;
        "smtp")     iptables -A INPUT -s "$ip" -p tcp --dport 25 -j ACCEPT ;;
        "pop3")     iptables -A INPUT -s "$ip" -p tcp --dport 110 -j ACCEPT ;;
        "imap")     iptables -A INPUT -s "$ip" -p tcp --dport 143 -j ACCEPT ;;
        "smb"|"samba") 
                    iptables -A INPUT -s "$ip" -p tcp --dport 139 -j ACCEPT 
                    iptables -A INPUT -s "$ip" -p tcp --dport 445 -j ACCEPT ;;
        "icmp")     iptables -A INPUT -s "$ip" -p icmp --icmp-type echo-request -j ACCEPT ;;
        *)          echo "[WARNING] Unknown protocol '$proto' in vars.sh for Scoreboard." ;;
    esac
}

for ip in "${SCOREBOARD_IPS[@]}"; do
    echo "[+] Whitelisting Scoreboard: $ip"
    # 1. SSH is always allowed for Scoreboard
    iptables -A INPUT -s "$ip" -p tcp --dport "$SSH_PORT" -j ACCEPT
    
    # 2. Allow other services defined in vars.sh
    for proto in "${ALLOWED_PROTOCOLS[@]}"; do
        allow_protocol_for_ip "$ip" "$proto"
    done
done

# ------------------------------------------------------------------------------
# 6. ANTI-NMAP BAN CHECK
# ------------------------------------------------------------------------------
if [ -n "$TRAP_PORT" ]; then
    modprobe xt_recent 2>/dev/null
    iptables -A INPUT -m recent --name PORT_SCANNER --update --seconds "$BAN_TIME" -j DROP
fi

# ------------------------------------------------------------------------------
# 7. PUBLIC SERVICES (General Access)
# ------------------------------------------------------------------------------
# SSH
echo "[+] Allowing SSH on Port: $SSH_PORT"
iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT

# Other Protocols (Same logic as Scoreboard but for ANY source IP)
for proto in "${ALLOWED_PROTOCOLS[@]}"; do
    case "$proto" in
        "http")     iptables -A INPUT -p tcp --dport 80 -j ACCEPT ;;
        "https")    iptables -A INPUT -p tcp --dport 443 -j ACCEPT ;;
        "dns")      iptables -A INPUT -p udp --dport 53 -j ACCEPT
                    iptables -A INPUT -p tcp --dport 53 -j ACCEPT ;;
        "mysql")    iptables -A INPUT -p tcp --dport 3306 -j ACCEPT ;;
        "postgresql"|"pgsql") iptables -A INPUT -p tcp --dport 5432 -j ACCEPT ;;
        "ftp")      iptables -A INPUT -p tcp --dport 21 -j ACCEPT ;;
        "smtp")     iptables -A INPUT -p tcp --dport 25 -j ACCEPT ;;
        "pop3")     iptables -A INPUT -p tcp --dport 110 -j ACCEPT ;;
        "imap")     iptables -A INPUT -p tcp --dport 143 -j ACCEPT ;;
        "smb"|"samba") 
                    iptables -A INPUT -p tcp --dport 139 -j ACCEPT 
                    iptables -A INPUT -p tcp --dport 445 -j ACCEPT ;;
        "icmp")     iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT ;;
        *)          echo "[WARNING] Unknown protocol '$proto' in vars.sh." ;;
    esac
done

# ------------------------------------------------------------------------------
# 8. THE TRAP
# ------------------------------------------------------------------------------
if [ -n "$TRAP_PORT" ]; then
    iptables -A INPUT -p tcp --dport "$TRAP_PORT" -m recent --name PORT_SCANNER --set -j LOG --log-prefix "TRAP_TRIGGERED: " --log-level 4
    iptables -A INPUT -p tcp --dport "$TRAP_PORT" -j DROP
fi

echo "[OK] Firewall applied successfully."
echo "     -> Docker Mode: $USE_DOCKER"
echo "     -> Trap Port: $TRAP_PORT"