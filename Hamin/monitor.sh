#!/bin/bash
# ==============================================================================
# SCRIPT: monitor.sh (Final: Trap Integrated + User Activity)
# ==============================================================================

# 1. Import Configuration
if [ -f "./vars.sh" ]; then source ./vars.sh; else echo "vars.sh missing"; exit 1; fi

while true; do
    clear
    echo "=========================================================="
    echo "   [ CCDC DEFENSE DASHBOARD ] - $(date +%T)"
    echo "   Docker Mode: $USE_DOCKER | Trap Port: $TRAP_PORT"
    echo "=========================================================="
    
    # --------------------------------------------------------------------------
    # [1] BANNED ATTACKERS (The Jail)
    # Reads IPs banned by firewall_safe.sh directly from the xt_recent module.
    # --------------------------------------------------------------------------
    echo -e "\n[1] BANNED ATTACKERS (Instant Ban List)"
    if [ -f /proc/net/xt_recent/PORT_SCANNER ]; then
        # If xt_recent file exists, print the IPs (Show last 5)
        awk '{print "   [X] BANNED: " $1}' /proc/net/xt_recent/PORT_SCANNER | head -n 5
        
        # Check if the list is empty
        lines=$(wc -l < /proc/net/xt_recent/PORT_SCANNER)
        if [ "$lines" -eq 0 ]; then echo "   [Safe] No attackers caught yet."; fi
    else
        echo "   [Info] Trap module not active or no bans yet."
    fi

    # --------------------------------------------------------------------------
    # [2] ACTIVE CONNECTIONS (Current Sessions)
    # --------------------------------------------------------------------------
    echo -e "\n----------------------------------------------------------"
    echo -e "[2] ACTIVE CONNECTIONS (ESTABLISHED)"
    ss -tun | grep ESTAB | awk '{print "   " $5, "->", $6}' | head -n 5

    # --------------------------------------------------------------------------
    # [3] OPEN PORTS AUDIT (Color Coded)
    # --------------------------------------------------------------------------
    echo -e "\n----------------------------------------------------------"
    echo -e "[3] OPEN PORTS AUDIT"
    
    # Get listening ports
    LISTENING_PORTS=$(netstat -tuln | awk 'NR>2 {print $4}' | awk -F: '{print $NF}' | sort -n | uniq)
    
    for port in $LISTENING_PORTS; do
        STATUS="[UNKNOWN]"
        COLOR="\e[33m" # Yellow (Default)
        
        # 3.1 Check Safe Protocols (Green)
        if [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "ssh" ]] && [[ "$port" == "$SSH_PORT" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "http" ]] && [[ "$port" == "80" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "https" ]] && [[ "$port" == "443" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "dns" ]] && [[ "$port" == "53" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
            
        # 3.2 Check TRAP PORT (Cyan) - Verifies if the Trap is active
        elif [[ "$port" == "$TRAP_PORT" ]]; then
            STATUS="[*** TRAP ACTIVE ***]"; COLOR="\e[36m" # Cyan
            
        # 3.3 Suspicious (Red)
        else
            STATUS="[SUSPICIOUS!]"; COLOR="\e[31m" # Red
        fi
        
        echo -e "   Port $port \t-> ${COLOR}${STATUS}\e[0m"
    done

    # --------------------------------------------------------------------------
    # [4] TRAP LOGS (Real-time Alerts)
    # --------------------------------------------------------------------------
    echo -e "\n----------------------------------------------------------"
    echo -e "[4] TRAP LOGS (Recent Triggers)"
    if command -v dmesg &> /dev/null; then
        # Search kernel logs for our configured prefix (TRAP_TRIGGERED)
        dmesg | grep "TRAP_TRIGGERED" | tail -n 3 | awk -F] '{print "   [!] " $2}'
    fi
    
    # --------------------------------------------------------------------------
    # [5] USER ACTIVITY (Suspicious Users)
    # --------------------------------------------------------------------------
    echo -e "\n----------------------------------------------------------"
    echo -e "[5] USER ACTIVITY (Check UID 0)"
    
    # Check current logged in users
    w | head -n 5
    
    # Quick check for users with UID 0 other than root
    echo -e "\n   [!] UID 0 Check (Should only be root):"
    awk -F: '($3 == 0) {print "       -> " $1}' /etc/passwd
    
    sleep 2
done