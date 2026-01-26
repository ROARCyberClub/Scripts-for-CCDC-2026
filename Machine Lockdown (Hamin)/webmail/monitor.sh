#!/bin/bash
# ==============================================================================
# SCRIPT: monitor.sh (Webmail Defense Dashboard)
# PURPOSE: Real-time monitoring with mail service status and keyboard controls
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
LAST_CONNECTION_COUNT=0

# ------------------------------------------------------------------------------
# 2. HELPER FUNCTIONS
# ------------------------------------------------------------------------------
log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MONITOR_LOG"
}

get_connection_count() {
    ss -tun 2>/dev/null | grep -c ESTAB || echo 0
}

check_alerts() {
    local current_conns=$(get_connection_count)
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
    echo "        WEBMAIL SERVER DASHBOARD v2.0 - $(date +%H:%M:%S)"
    echo "======================================================================"
    echo -e "${NC}"
    echo -e "${YELLOW}Controls: [q] Quit  [p] Panic  [r] Refresh  [a] Audit  [m] Mail restart${NC}"
    echo ""
}

draw_mail_status() {
    echo -e "${BOLD}[1] MAIL SERVICE STATUS${NC}"
    echo "----------------------------------------------------------------------"
    
    # Postfix
    if systemctl is-active --quiet postfix 2>/dev/null; then
        echo -e "   ${GREEN}[OK]${NC} Postfix (SMTP) is running"
    else
        echo -e "   ${RED}[X]${NC} Postfix (SMTP) is NOT running!"
        log_event "ALERT: Postfix is down!"
    fi
    
    # Dovecot
    if systemctl is-active --quiet dovecot 2>/dev/null; then
        echo -e "   ${GREEN}[OK]${NC} Dovecot (IMAP/POP3) is running"
    else
        echo -e "   ${RED}[X]${NC} Dovecot (IMAP/POP3) is NOT running!"
        log_event "ALERT: Dovecot is down!"
    fi
    
    # Web interface (httpd or nginx)
    if systemctl is-active --quiet httpd 2>/dev/null; then
        echo -e "   ${GREEN}[OK]${NC} Apache (httpd) is running"
    elif systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "   ${GREEN}[OK]${NC} Nginx is running"
    else
        echo -e "   ${YELLOW}[?]${NC} Web server status unknown"
    fi
    
    echo ""
    echo "   Mail Ports:"
    for port in ${MAIL_SMTP_PORT:-25} ${MAIL_IMAP_PORT:-143} ${MAIL_POP3_PORT:-110}; do
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "     ${GREEN}[OK]${NC} Port $port: LISTENING"
        else
            echo -e "     ${RED}[X]${NC} Port $port: NOT LISTENING"
        fi
    done
    echo ""
}

draw_firewall_status() {
    echo -e "${BOLD}[2] FIREWALL STATUS (firewalld)${NC}"
    echo "----------------------------------------------------------------------"
    
    if command_exists firewall-cmd; then
        local zone=$(firewall-cmd --get-default-zone 2>/dev/null)
        local status=$(systemctl is-active firewalld 2>/dev/null)
        
        if [ "$status" == "active" ]; then
            echo -e "   ${GREEN}[OK]${NC} firewalld is active (zone: $zone)"
        else
            echo -e "   ${RED}[X]${NC} firewalld is NOT running!"
        fi
        
        echo ""
        echo "   Open ports:"
        firewall-cmd --list-ports 2>/dev/null | tr ' ' '\n' | while read port; do
            [ -n "$port" ] && echo "     - $port"
        done
    else
        echo -e "   ${YELLOW}[?]${NC} firewall-cmd not found"
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
    echo "----------------------------------------------------------------------"
    
    local ports=$(ss -tuln 2>/dev/null | awk 'NR>1 {print $5}' | awk -F: '{print $NF}' | sort -n | uniq)
    
    for port in $ports; do
        [ -z "$port" ] && continue
        
        local status="[?]"
        local color="$YELLOW"
        
        case "$port" in
            "$SSH_PORT") status="[SSH]"; color="$GREEN" ;;
            "80") status="[HTTP]"; color="$GREEN" ;;
            "443") status="[HTTPS]"; color="$GREEN" ;;
            "${MAIL_SMTP_PORT:-25}") status="[SMTP]"; color="$GREEN" ;;
            "${MAIL_IMAP_PORT:-143}") status="[IMAP]"; color="$GREEN" ;;
            "${MAIL_POP3_PORT:-110}") status="[POP3]"; color="$GREEN" ;;
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
            warn "PANIC MODE - Opening all ports!"
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
        m|M)
            echo ""
            warn "Restarting mail services..."
            systemctl restart postfix 2>/dev/null
            systemctl restart dovecot 2>/dev/null
            success "Mail services restarted"
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
    draw_mail_status
    draw_firewall_status
    draw_connections
    draw_ports
    draw_users
    draw_footer
    handle_input
done