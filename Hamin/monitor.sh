#!/bin/bash
# ==============================================================================
# SCRIPT: monitor.sh (Dashboard)
# PURPOSE: Monitors Scoreboard status and Suspicious Ports
# ==============================================================================

# Import Config
if [ -f "./vars.sh" ]; then source ./vars.sh; fi

while true; do
    clear
    echo "=========================================================="
    echo "   [ CCDC DEFENSE DASHBOARD ] - $(date +%T)"
    echo "=========================================================="
    
    # 1. ESTABLISHED CONNECTIONS (Who is connected?)
    echo -e "\n[1] ACTIVE CONNECTIONS (Red Team?)"
    ss -tun | grep ESTAB | awk '{print $5, "->", $6}' | head -n 5

    # 2. OPEN PORTS CHECK (The Logic Upgrade)
    echo -e "\n----------------------------------------------------------"
    echo -e "[2] OPEN PORTS AUDIT"
    
    # Get all listening ports (TCP/UDP)
    LISTENING_PORTS=$(netstat -tuln | awk 'NR>2 {print $4}' | awk -F: '{print $NF}' | sort -n | uniq)
    
    for port in $LISTENING_PORTS; do
        STATUS="[UNKNOWN]"
        COLOR="\e[33m" # Yellow
        
        # Check against ALLOWED_PROTOCOLS from vars.sh
        # Logic: If protocol is in ALLOWED_PROTOCOLS AND port matches standard port
        if [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "ssh" ]] && [[ "$port" == "22" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m" # Green
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "http" ]] && [[ "$port" == "80" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "https" ]] && [[ "$port" == "443" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "dns" ]] && [[ "$port" == "53" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        else
            STATUS="[SUSPICIOUS!]"; COLOR="\e[31m" # Red
        fi
        
        echo -e "   Port $port \t-> ${COLOR}${STATUS}\e[0m"
    done

    # 3. TRAP LOGS
    echo -e "\n----------------------------------------------------------"
    echo -e "[3] HONEY POT HITS"
    if command -v dmesg &> /dev/null; then
        dmesg | grep "TRAP_TRIGGERED" | tail -n 3 | awk '{print $NF}'
    fi
    
    sleep 3

    # 4. USER ACTIVITY
    echo -e "\n----------------------------------------------------------"
    echo -e "[4] SUSPICIOUS USERS (Check UID 0 or New Users)"
    # Check current logged in users
    w | head -n 5
    # Quick check for users with UID 0 other than root
    echo -e "\n[!] UID 0 Users (Should only be root):"
    awk -F: '($3 == 0) {print $1}' /etc/passwd
done