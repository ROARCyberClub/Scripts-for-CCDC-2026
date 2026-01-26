#!/bin/bash
# ==============================================================================
# SCRIPT: monitor.sh (Workstation Defense Dashboard)
# PURPOSE: Real-time monitoring for general workstation
# USAGE: sudo ./monitor.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

# ------------------------------------------------------------------------------
# 1. CONFIGURATION
# ------------------------------------------------------------------------------
REFRESH_INTERVAL=3
MONITOR_LOG="${LOG_DIR}/monitor_$(date +%Y%m%d).log"
mkdir -p "$LOG_DIR" 2>/dev/null

ALERT_MAX_CONNECTIONS=20
ALERT_MAX_BANNED=5
LAST_BANNED_COUNT=0
LAST_CONNECTION_COUNT=0

# ------------------------------------------------------------------------------
# 2. HELPER FUNCTIONS
# ------------------------------------------------------------------------------
log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MONITOR_LOG"
}

get_banned_count() {
    if [ -f /proc/net/xt_recent/PORT_SCANNER ]; then
        wc -l < /proc/net/xt_recent/PORT_SCANNER
    else
        echo 0
    fi
}

get_connection_count() {
    ss -tun 2>/dev/null | grep -c ESTAB || echo 0
}

check_alerts() {
    local current_banned=$(get_banned_count)
    local current_conns=$(get_connection_count)
    
    if [ "$current_banned" -gt "$LAST_BANNED_COUNT" ]; then
        log_event "ALERT: New IP(s) banned!"
    fi
    LAST_BANNED_COUNT=$current_banned
    
    if [ "$current_conns" -gt "$ALERT_MAX_CONNECTIONS" ]; then
        log_event "ALERT: High connection count: $current_conns"
    fi
    LAST_CONNECTION_COUNT=$current_conns
}

# ------------------------------------------------------------------------------
# 3. DISPLAY FUNCTIONS
# ------------------------------------------------------------------------------

draw_header() {
    echo -e "${BOLD}${CYAN}"
    echo "======================================================================"
    echo "       WORKSTATION DASHBOARD v2.0 - $(date +%H:%M:%S)"
    echo "======================================================================"
    echo -e "${NC}"
    echo -e "${YELLOW}Controls: [q] Quit  [p] Panic  [r] Refresh  [a] Audit${NC}"
    echo ""
}

draw_system_status() {
    echo -e "${BOLD}[1] SYSTEM STATUS${NC}"
    echo "----------------------------------------------------------------------"
    
    # SSH
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        echo -e "   ${GREEN}[OK]${NC} SSH is running"
    else
        echo -e "   ${RED}[X]${NC} SSH is NOT running!"
        log_event "ALERT: SSH is down!"
    fi
    
    # Uptime
    echo "   Uptime: $(uptime -p 2>/dev/null || echo 'unknown')"
    
    # Load
    echo "   Load: $(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')"
    
    echo ""
}

draw_banned() {
    echo -e "${BOLD}[2] BANNED ATTACKERS (Honeypot)${NC}"
    echo "----------------------------------------------------------------------"
    
    if [ -f /proc/net/xt_recent/PORT_SCANNER ]; then
        local count=$(wc -l < /proc/net/xt_recent/PORT_SCANNER)
        if [ "$count" -gt 0 ]; then
            echo -e "${RED}"
            awk '{gsub(/src=/, ""); print "   BANNED: " $1}' /proc/net/xt_recent/PORT_SCANNER | head -n 5
            echo -e "${NC}"
            [ "$count" -gt 5 ] && echo "   ... and $((count - 5)) more"
        else
            echo -e "   ${GREEN}[OK]${NC} No attackers caught yet"
        fi
    else
        echo "   [i] Trap module not active"
    fi
    echo ""
}

draw_connections() {
    echo -e "${BOLD}[3] ACTIVE CONNECTIONS${NC}"
    echo "----------------------------------------------------------------------"
    
    local conns=$(ss -tun 2>/dev/null | grep ESTAB | head -n 8)
    if [ -n "$conns" ]; then
        echo "$conns" | awk '{
            split($5, local, ":")
            split($6, remote, ":")
            printf "   %s:%s <- %s:%s\n", local[1], local[2], remote[1], remote[2]
        }'
        
        local total=$(ss -tun 2>/dev/null | grep -c ESTAB)
        [ "$total" -gt 8 ] && echo "   ... and $((total - 8)) more"
    else
        echo "   No active connections"
    fi
    echo ""
}

draw_ports() {
    echo -e "${BOLD}[4] OPEN PORTS AUDIT${NC}"
    echo "----------------------------------------------------------------------"
    
    local ports=$(ss -tuln 2>/dev/null | awk 'NR>1 {print $5}' | awk -F: '{print $NF}' | sort -n | uniq)
    
    for port in $ports; do
        [ -z "$port" ] && continue
        
        local status="[?]"
        local color="$YELLOW"
        
        case "$port" in
            "$SSH_PORT") status="[SSH]"; color="$GREEN" ;;
            "$TRAP_PORT") status="[TRAP]"; color="$CYAN" ;;
            *) status="[CHECK!]"; color="$RED" ;;
        esac
        
        echo -e "   Port ${BOLD}$port${NC}  ${color}${status}${NC}"
    done
    echo ""
}

draw_users() {
    echo -e "${BOLD}[5] USER ACTIVITY${NC}"
    echo "----------------------------------------------------------------------"
    
    echo "   Currently logged in:"
    w -h 2>/dev/null | awk '{printf "     - %s (%s) %s\n", $1, $3, $5}' | head -n 5
    
    echo ""
    echo "   UID 0 accounts:"
    awk -F: '($3 == 0) {print $1}' /etc/passwd | while read u; do
        if [ "$u" == "root" ]; then
            echo -e "     ${GREEN}[OK]${NC} $u"
        else
            echo -e "     ${RED}[!]${NC} $u (SUSPICIOUS!)"
            log_event "ALERT: Non-root UID 0 user: $u"
        fi
    done
    echo ""
}

draw_footer() {
    echo "----------------------------------------------------------------------"
    echo -e "Log: ${CYAN}$MONITOR_LOG${NC}"
}

# ------------------------------------------------------------------------------
# 4. KEYBOARD HANDLER
# ------------------------------------------------------------------------------
handle_input() {
    local key
    read -rsn1 -t "$REFRESH_INTERVAL" key || return
    
    case "$key" in
        q|Q)
            echo ""
            info "Exiting monitor..."
            exit 0
            ;;
        p|P)
            echo ""
            warn "PANIC MODE!"
            [ -f "./panic.sh" ] && ./panic.sh
            read -p "Press Enter to continue..."
            ;;
        r|R) ;;
        a|A)
            echo ""
            info "Running security audit..."
            [ -f "./audit.sh" ] && ./audit.sh
            read -p "Press Enter to continue..."
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 5. MAIN LOOP
# ------------------------------------------------------------------------------
trap 'echo ""; info "Monitor stopped."; exit 0' SIGINT SIGTERM

log_event "Monitor started"

while true; do
    clear
    check_alerts
    draw_header
    draw_system_status
    draw_banned
    draw_connections
    draw_ports
    draw_users
    draw_footer
    handle_input
done