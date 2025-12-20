#!/bin/bash
# ==============================================================================
# SCRIPT: monitor.sh (Final: Full Protocol Support)
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
    # --------------------------------------------------------------------------
    echo -e "\n[1] BANNED ATTACKERS (Instant Ban List)"
    if [ -f /proc/net/xt_recent/PORT_SCANNER ]; then
        awk '{print "   [X] BANNED: " $1}' /proc/net/xt_recent/PORT_SCANNER | head -n 5
        lines=$(wc -l < /proc/net/xt_recent/PORT_SCANNER)
        if [ "$lines" -eq 0 ]; then echo "   [Safe] No attackers caught yet."; fi
    else
        echo "   [Info] Trap module not active or no bans yet."
    fi

    # --------------------------------------------------------------------------
    # [2] ACTIVE CONNECTIONS
    # --------------------------------------------------------------------------
    echo -e "\n----------------------------------------------------------"
    echo -e "[2] ACTIVE CONNECTIONS (ESTABLISHED)"
    ss -tun | grep ESTAB | awk '{print "   " $5, "->", $6}' | head -n 5

    # --------------------------------------------------------------------------
    # [3] OPEN PORTS AUDIT (Updated for ALL Protocols)
    # --------------------------------------------------------------------------
    echo -e "\n----------------------------------------------------------"
    echo -e "[3] OPEN PORTS AUDIT"
    
    # Get listening ports
    LISTENING_PORTS=$(netstat -tuln | awk 'NR>2 {print $4}' | awk -F: '{print $NF}' | sort -n | uniq)
    
    for port in $LISTENING_PORTS; do
        STATUS="[UNKNOWN]"
        COLOR="\e[33m" # Yellow (Default)
        
        # 3.1 Check SSH (Dynamic Port)
        if [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "ssh" ]] && [[ "$port" == "$SSH_PORT" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
            
        # 3.2 Check Standard Web & DNS
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "http" ]] && [[ "$port" == "80" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "https" ]] && [[ "$port" == "443" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "dns" ]] && [[ "$port" == "53" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
            
        # 3.3 Check Databases
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "mysql" ]] && [[ "$port" == "3306" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "postgresql" || " ${ALLOWED_PROTOCOLS[*]} " =~ "pgsql" ]] && [[ "$port" == "5432" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
            
        # 3.4 Check Mail & FTP
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "ftp" ]] && [[ "$port" == "21" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "smtp" ]] && [[ "$port" == "25" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "pop3" ]] && [[ "$port" == "110" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "imap" ]] && [[ "$port" == "143" ]]; then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"
            
        # 3.5 Check SMB (Samba)
        elif [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "smb" || " ${ALLOWED_PROTOCOLS[*]} " =~ "samba" ]] && ([[ "$port" == "139" ]] || [[ "$port" == "445" ]]); then
            STATUS="[SCORED/SAFE]"; COLOR="\e[32m"

        # 3.6 Check TRAP PORT (Cyan)
        elif [[ "$port" == "$TRAP_PORT" ]]; then
            STATUS="[*** TRAP ACTIVE ***]"; COLOR="\e[36m" # Cyan
            
        # 3.7 Suspicious (Red)
        else
            STATUS="[SUSPICIOUS!]"; COLOR="\e[31m" # Red
        fi
        
        echo -e "   Port $port \t-> ${COLOR}${STATUS}\e[0m"
    done

    # --------------------------------------------------------------------------
    # [4] TRAP LOGS
    # --------------------------------------------------------------------------
    echo -e "\n----------------------------------------------------------"
    echo -e "[4] TRAP LOGS (Recent Triggers)"
    if command -v dmesg &> /dev/null; then
        dmesg | grep "TRAP_TRIGGERED" | tail -n 3 | awk -F] '{print "   [!] " $2}'
    fi
    
    # --------------------------------------------------------------------------
    # [5] USER ACTIVITY
    # --------------------------------------------------------------------------
    echo -e "\n----------------------------------------------------------"
    echo -e "[5] USER ACTIVITY (Check UID 0)"
    w | head -n 5
    echo -e "\n   [!] UID 0 Check (Should only be root):"
    awk -F: '($3 == 0) {print "       -> " $1}' /etc/passwd
    
    sleep 2
done