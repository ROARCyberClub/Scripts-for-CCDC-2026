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
        
        # Check against SCORED_SERVICES (Simplified Logic for Dashboard)
        # This is a basic check. You can expand mapping logic if needed.
        if [[ " ${SCORED_SERVICES[*]} " =~ "ssh" ]] && [[ "$port" == "22" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m" # Green
        elif [[ " ${SCORED_SERVICES[*]} " =~ "http" ]] && [[ "$port" == "80" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${SCORED_SERVICES[*]} " =~ "dns" ]] && [[ "$port" == "53" ]]; then
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
done