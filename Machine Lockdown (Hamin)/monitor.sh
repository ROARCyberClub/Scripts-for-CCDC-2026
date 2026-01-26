#!/bin/bash
# ==============================================================================
# SCRIPT: monitor.sh (Splunk Defense Dashboard)
# PURPOSE: Real-time monitoring with Splunk status and keyboard controls
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

# Track state for alerts
LAST_CONNECTION_COUNT=0

# ------------------------------------------------------------------------------
# 2. HELPER FUNCTIONS
# ------------------------------------------------------------------------------

# Play alert sound (if available)
play_alert() {
    if command_exists paplay; then
        paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null &
    elif command_exists aplay; then
        echo -e '\a'
    fi
}

# Log event to monitor log
log_event() {
    local event="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $event" >> "$MONITOR_LOG"
}

# Get active connection count
get_connection_count() {
    ss -tun 2>/dev/null | grep -c ESTAB || echo 0
}

# Check for new threats
check_alerts() {
    local current_conns=$(get_connection_count)
    
    # Too many connections
    if [ "$current_conns" -gt "$ALERT_MAX_CONNECTIONS" ] && [ "$current_conns" -gt "$LAST_CONNECTION_COUNT" ]; then
        log_event "ALERT: High connection count: $current_conns"
        play_alert
    fi
    LAST_CONNECTION_COUNT=$current_conns
}

# ------------------------------------------------------------------------------
# 3. DISPLAY FUNCTIONS
# ------------------------------------------------------------------------------

draw_header() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║        SPLUNK SERVER DASHBOARD v2.0 - $(date +%H:%M:%S)                 ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo -e "║  Firewall: firewalld | Trap: ${TRAP_PORT} | Refresh: ${REFRESH_INTERVAL}s                     ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}Controls: [q] Quit  [p] Panic  [r] Refresh  [a] Audit  [s] Splunk restart${NC}"
    echo ""
}

draw_splunk_status() {
    echo -e "${BOLD}[1] SPLUNK STATUS${NC}"
    echo "────────────────────────────────────────────────────"
    
    local splunk_bin="${SPLUNK_HOME:-/opt/splunk}/bin/splunk"
    
    if [ -x "$splunk_bin" ]; then
        local status=$("$splunk_bin" status 2>/dev/null | head -n 1)
        if echo "$status" | grep -qi "running"; then
            echo -e "   ${GREEN}✓ Splunk is RUNNING${NC}"
        else
            echo -e "   ${RED}✗ Splunk is NOT RUNNING!${NC}"
            log_event "ALERT: Splunk service is down!"
        fi
        
        # Show Splunk version
        local version=$("$splunk_bin" version 2>/dev/null | head -n 1)
        [ -n "$version" ] && echo "   Version: $version"
    else
        # Try systemd
        if systemctl is-active --quiet Splunkd 2>/dev/null; then
            echo -e "   ${GREEN}✓ Splunkd service is running${NC}"
        elif systemctl is-active --quiet splunk 2>/dev/null; then
            echo -e "   ${GREEN}✓ Splunk service is running${NC}"
        else
            echo -e "   ${YELLOW}? Splunk status unknown (${splunk_bin} not found)${NC}"
        fi
    fi
    
    # Show listening Splunk ports
    echo ""
    echo "   Splunk Ports:"
    for port in ${SPLUNK_WEB_PORT:-8000} ${SPLUNK_FORWARDER_PORT:-9997} ${SPLUNK_MGMT_PORT:-8089}; do
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "     ${GREEN}✓${NC} Port $port: LISTENING"
        else
            echo -e "     ${RED}✗${NC} Port $port: NOT LISTENING"
        fi
    done
    echo ""
}

draw_firewall_status() {
    echo -e "${BOLD}[2] FIREWALL STATUS (firewalld)${NC}"
    echo "────────────────────────────────────────────────────"
    
    if command_exists firewall-cmd; then
        local zone=$(firewall-cmd --get-default-zone 2>/dev/null)
        local status=$(systemctl is-active firewalld 2>/dev/null)
        
        if [ "$status" == "active" ]; then
            echo -e "   ${GREEN}✓ firewalld is active${NC} (zone: $zone)"
        else
            echo -e "   ${RED}✗ firewalld is NOT running!${NC}"
        fi
        
        # Show open ports
        echo ""
        echo "   Open ports:"
        firewall-cmd --list-ports 2>/dev/null | tr ' ' '\n' | while read port; do
            [ -n "$port" ] && echo "     • $port"
        done
    else
        echo -e "   ${YELLOW}? firewall-cmd not found${NC}"
    fi
    echo ""
}

draw_connections() {
    echo -e "${BOLD}[3] ACTIVE CONNECTIONS${NC}"
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
    echo -e "${BOLD}[4] OPEN PORTS AUDIT${NC}"
    echo "────────────────────────────────────────────────────"
    
    local ports=$(ss -tuln 2>/dev/null | awk 'NR>1 {print $5}' | awk -F: '{print $NF}' | sort -n | uniq)
    
    for port in $ports; do
        [ -z "$port" ] && continue
        
        local status="[?]"
        local color="$YELLOW"
        
        case "$port" in
            "$SSH_PORT")
                status="[SSH]"; color="$GREEN"
                ;;
            "80")
                status="[HTTP]"; color="$GREEN"
                ;;
            "443")
                status="[HTTPS]"; color="$GREEN"
                ;;
            "${SPLUNK_WEB_PORT:-8000}")
                status="[SPLUNK WEB]"; color="$GREEN"
                ;;
            "${SPLUNK_FORWARDER_PORT:-9997}")
                status="[SPLUNK FWD]"; color="$GREEN"
                ;;
            "${SPLUNK_MGMT_PORT:-8089}")
                status="[SPLUNK API]"; color="$GREEN"
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
    echo -e "${BOLD}[5] RECENT TRAP EVENTS${NC}"
    echo "────────────────────────────────────────────────────"
    
    # Check journalctl for firewalld logs
    local traps=$(journalctl -k -n 50 2>/dev/null | grep "TRAP_TRIGGERED" | tail -n 3)
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
    echo -e "${BOLD}[6] USER ACTIVITY${NC}"
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
        s|S)
            echo ""
            warn "Restarting Splunk..."
            local splunk_bin="${SPLUNK_HOME:-/opt/splunk}/bin/splunk"
            if [ -x "$splunk_bin" ]; then
                "$splunk_bin" restart
            else
                warn "Splunk binary not found at $splunk_bin"
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
    draw_splunk_status
    draw_firewall_status
    draw_connections
    draw_ports
    draw_trap_logs
    draw_users
    draw_footer
    
    # Handle keyboard input (with timeout = refresh interval)
    handle_input
done