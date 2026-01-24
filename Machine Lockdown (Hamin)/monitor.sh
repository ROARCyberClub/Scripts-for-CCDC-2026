#!/bin/bash
# ==============================================================================
# SCRIPT: monitor.sh (Enhanced Defense Dashboard)
# PURPOSE: Real-time monitoring with logging and keyboard controls
# USAGE: sudo ./monitor.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load dependencies
source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

# ------------------------------------------------------------------------------
# 1. CONFIGURATION
# ------------------------------------------------------------------------------
REFRESH_INTERVAL=3
MONITOR_LOG="${LOG_DIR}/monitor_$(date +%Y%m%d).log"

# Ensure log directory exists
mkdir -p "$LOG_DIR" 2>/dev/null

# Alert thresholds
ALERT_MAX_CONNECTIONS=20
ALERT_MAX_BANNED=5

# Track state for alerts
LAST_BANNED_COUNT=0
LAST_CONNECTION_COUNT=0

# ------------------------------------------------------------------------------
# 2. HELPER FUNCTIONS
# ------------------------------------------------------------------------------

# Play alert sound (if available)
play_alert() {
    # Try different methods
    if command_exists paplay; then
        paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null &
    elif command_exists aplay; then
        echo -e '\a' # Terminal bell
    fi
}

# Log event to monitor log
log_event() {
    local event="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $event" >> "$MONITOR_LOG"
}

# Get banned IP count
get_banned_count() {
    if [ -f /proc/net/xt_recent/PORT_SCANNER ]; then
        wc -l < /proc/net/xt_recent/PORT_SCANNER
    else
        echo 0
    fi
}

# Get active connection count
get_connection_count() {
    ss -tun 2>/dev/null | grep -c ESTAB || echo 0
}

# Check for new threats
check_alerts() {
    local current_banned=$(get_banned_count)
    local current_conns=$(get_connection_count)
    
    # New banned IPs
    if [ "$current_banned" -gt "$LAST_BANNED_COUNT" ]; then
        local new_bans=$((current_banned - LAST_BANNED_COUNT))
        log_event "ALERT: $new_bans new IP(s) banned!"
        play_alert
    fi
    LAST_BANNED_COUNT=$current_banned
    
    # Too many connections
    if [ "$current_conns" -gt "$ALERT_MAX_CONNECTIONS" ] && [ "$current_conns" -gt "$LAST_CONNECTION_COUNT" ]; then
        log_event "ALERT: High connection count: $current_conns"
    fi
    LAST_CONNECTION_COUNT=$current_conns
}

# ------------------------------------------------------------------------------
# 3. DISPLAY FUNCTIONS
# ------------------------------------------------------------------------------

draw_header() {
    local mode_str=""
    [ "$USE_DOCKER" == "true" ] && mode_str+="Docker "
    [ "$USE_IPV6" == "true" ] && mode_str+="IPv6 "
    
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║           CCDC DEFENSE DASHBOARD v2.0 - $(date +%H:%M:%S)                ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo -e "║  Mode: ${mode_str:-Standard}| Trap: ${TRAP_PORT} | Refresh: ${REFRESH_INTERVAL}s                       ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}Controls: [q] Quit  [p] Panic  [r] Refresh  [a] Run Audit${NC}"
    echo ""
}

draw_banned() {
    echo -e "${BOLD}[1] BANNED ATTACKERS (Honeypot Triggered)${NC}"
    echo "────────────────────────────────────────────────────"
    
    if [ -f /proc/net/xt_recent/PORT_SCANNER ]; then
        local count=$(wc -l < /proc/net/xt_recent/PORT_SCANNER)
        if [ "$count" -gt 0 ]; then
            echo -e "${RED}"
            awk '{
                # Extract IP address (first field) and timestamp
                gsub(/src=/, "")
                print "   ☠  BANNED: " $1
            }' /proc/net/xt_recent/PORT_SCANNER | head -n 5
            echo -e "${NC}"
            if [ "$count" -gt 5 ]; then
                echo "   ... and $((count - 5)) more"
            fi
        else
            echo -e "   ${GREEN}✓ No attackers caught yet${NC}"
        fi
    else
        echo "   [i] Trap module not active or no bans"
    fi
    echo ""
}

draw_connections() {
    echo -e "${BOLD}[2] ACTIVE CONNECTIONS${NC}"
    echo "────────────────────────────────────────────────────"
    
    local conns=$(ss -tun 2>/dev/null | grep ESTAB | head -n 8)
    if [ -n "$conns" ]; then
        echo "$conns" | awk '{
            split($5, local, ":")
            split($6, remote, ":")
            printf "   %s:%s <- %s:%s\n", local[1], local[2], remote[1], remote[2]
        }'
        
        local total=$(ss -tun 2>/dev/null | grep -c ESTAB)
        if [ "$total" -gt 8 ]; then
            echo "   ... and $((total - 8)) more connections"
        fi
    else
        echo "   No active connections"
    fi
    echo ""
}

draw_ports() {
    echo -e "${BOLD}[3] OPEN PORTS AUDIT${NC}"
    echo "────────────────────────────────────────────────────"
    
    local ports=$(netstat -tuln 2>/dev/null | awk 'NR>2 {print $4}' | awk -F: '{print $NF}' | sort -n | uniq)
    
    for port in $ports; do
        [ -z "$port" ] && continue
        
        local status="[?]"
        local color="$YELLOW"
        
        # Check if port is in allowed protocols
        case "$port" in
            "$SSH_PORT")
                if [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "ssh" ]]; then
                    status="[SCORED]"; color="$GREEN"
                fi
                ;;
            "80")
                if [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "http" ]]; then
                    status="[SCORED]"; color="$GREEN"
                fi
                ;;
            "443")
                if [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "https" ]]; then
                    status="[SCORED]"; color="$GREEN"
                fi
                ;;
            "53")
                if [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "dns" ]]; then
                    status="[SCORED]"; color="$GREEN"
                fi
                ;;
            "3306")
                if [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "mysql" ]]; then
                    status="[SCORED]"; color="$GREEN"
                fi
                ;;
            "5432")
                if [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "postgresql" ]] || [[ " ${ALLOWED_PROTOCOLS[*]} " =~ "pgsql" ]]; then
                    status="[SCORED]"; color="$GREEN"
                fi
                ;;
            "$TRAP_PORT")
                status="[TRAP]"; color="$CYAN"
                ;;
            *)
                status="[CHECK!]"; color="$RED"
                ;;
        esac
        
        echo -e "   Port ${BOLD}$port${NC}  ${color}${status}${NC}"
    done
    echo ""
}

draw_trap_logs() {
    echo -e "${BOLD}[4] RECENT TRAP EVENTS${NC}"
    echo "────────────────────────────────────────────────────"
    
    local traps=$(dmesg 2>/dev/null | grep "TRAP_TRIGGERED" | tail -n 3)
    if [ -n "$traps" ]; then
        echo -e "${RED}"
        echo "$traps" | awk -F'TRAP_TRIGGERED: ' '{print "   ⚠  " $2}'
        echo -e "${NC}"
    else
        echo "   No trap events in kernel log"
    fi
    echo ""
}

draw_users() {
    echo -e "${BOLD}[5] USER ACTIVITY${NC}"
    echo "────────────────────────────────────────────────────"
    
    # Logged in users
    echo "   Currently logged in:"
    w -h 2>/dev/null | awk '{printf "     - %s (%s) %s\n", $1, $3, $5}' | head -n 5
    
    # UID 0 check
    echo ""
    echo "   UID 0 accounts (should only be root):"
    local uid0=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)
    for u in $uid0; do
        if [ "$u" == "root" ]; then
            echo -e "     ${GREEN}✓ $u${NC}"
        else
            echo -e "     ${RED}⚠ $u (SUSPICIOUS!)${NC}"
            log_event "ALERT: Non-root UID 0 user detected: $u"
        fi
    done
    echo ""
}

draw_footer() {
    echo "────────────────────────────────────────────────────"
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
            warn "PANIC MODE - Opening all ports!"
            if [ -f "./panic.sh" ]; then
                ./panic.sh
            fi
            read -p "Press Enter to continue monitoring..."
            ;;
        r|R)
            # Force refresh (do nothing, loop will redraw)
            ;;
        a|A)
            echo ""
            info "Running security audit..."
            if [ -f "./audit.sh" ]; then
                ./audit.sh
            else
                warn "audit.sh not found"
            fi
            read -p "Press Enter to continue monitoring..."
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 5. MAIN LOOP
# ------------------------------------------------------------------------------

# Trap Ctrl+C for clean exit
trap 'echo ""; info "Monitor stopped."; exit 0' SIGINT SIGTERM

log_event "Monitor started"

while true; do
    clear
    
    # Check for alerts
    check_alerts
    
    # Draw dashboard
    draw_header
    draw_banned
    draw_connections
    draw_ports
    draw_trap_logs
    draw_users
    draw_footer
    
    # Handle keyboard input (with timeout = refresh interval)
    handle_input
done