#!/bin/bash
# ==============================================================================
# SCRIPT: vyos_hardening.sh (Topology Aware)
# PURPOSE: Generate VyOS config for CCDC 2026 Topology (VyOS -> PA/FTD -> Server)
# USAGE: ./vyos_hardening.sh
# ==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values based on Topology
DEFAULT_TIMEZONE="America/Chicago"
DEFAULT_NTP="pool.ntp.org"

# Constants from Topology
PA_LINK_IP="172.16.101.254"     # Net1 Gateway (Palo Alto Outside)
FTD_LINK_IP="172.16.102.254"    # Net2 Gateway (Cisco FTD Outside)

LINUX_SUBNET="172.20.242.0/24"  # Behind Palo Alto
WIN_SUBNET="172.20.240.0/24"    # Behind Cisco FTD

ECOM_Inside_IP="172.20.242.30"
WEBMAIL_Inside_IP="172.20.242.40"
SPLUNK_Inside_IP="172.20.242.20"
AD_Inside_IP="172.20.240.102"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║      CCDC 2026 TOPOLOGY - VyOS CONFIG GENERATOR v2.0         ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  * Updates Static Routes for PA/FTD                          ║"
echo "║  * Calculates Public IPs based on Team Number                ║"
echo "║  * Configures 1:1 NAT for Ecom, Webmail, Splunk              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ------------------------------------------------------------------------------
# 1. GATHER TEAM INFORMATION
# ------------------------------------------------------------------------------

read -p "Enter your Team Number (1-20): " TEAM_NUM

if [[ ! "$TEAM_NUM" =~ ^[0-9]+$ ]]; then
    echo "Invalid Team Number"
    exit 1
fi

# Calculate IPs
WAN_OCTET=$((20 + TEAM_NUM))
WAN_IP="172.31.${WAN_OCTET}.2"
PUBLIC_POOL_PREFIX="172.25.${WAN_OCTET}"

echo -e "${GREEN}[*] Calculated Network Settings for Team $TEAM_NUM:${NC}"
echo "    - WAN IP: $WAN_IP/29"
echo "    - Public IP Pool: $PUBLIC_POOL_PREFIX.0/24"
echo ""

# Confirm Interfaces
read -p "Enter WAN Interface (default: eth0): " WAN_IF
WAN_IF=${WAN_IF:-eth0}
read -p "Enter Interface to Palo Alto (Net1, default: eth1): " PA_IF
PA_IF=${PA_IF:-eth1}
read -p "Enter Interface to Cisco FTD (Net2, default: eth2): " FTD_IF
FTD_IF=${FTD_IF:-eth2}

echo ""
echo -e "${YELLOW}[!] Generating configuration...${NC}"

# ------------------------------------------------------------------------------
# 2. GENERATE CONFIGURATION
# ------------------------------------------------------------------------------

OUTPUT_FILE="vyos_team${TEAM_NUM}_config.txt"

cat <<EOF > "$OUTPUT_FILE"
# ==============================================================================
# VyOS CONFIGURATION FOR TEAM $TEAM_NUM
# Generated on: $(date)
# ==============================================================================
configure

# ------------------------------------------------------------------------------
# 1. SYSTEM SETTINGS
# ------------------------------------------------------------------------------
set system host-name 'VyOS-Team$TEAM_NUM'
set system time-zone '$DEFAULT_TIMEZONE'
delete system ntp
set system ntp server $DEFAULT_NTP

# SSH (Listen on Internal Interfaces)
delete service ssh
set service ssh port 22
set service ssh listen-address 172.16.101.1
set service ssh listen-address 172.16.102.1

# ------------------------------------------------------------------------------
# 2. INTERFACES (Verify these!)
# ------------------------------------------------------------------------------
# WAN
set interfaces ethernet $WAN_IF address '$WAN_IP/29'
set interfaces ethernet $WAN_IF description 'WAN - OUTSIDE'

# Net1 (To Palo Alto)
set interfaces ethernet $PA_IF address '172.16.101.1/24'
set interfaces ethernet $PA_IF description 'Net1 - To Palo Alto'

# Net2 (To Cisco FTD)
set interfaces ethernet $FTD_IF address '172.16.102.1/24'
set interfaces ethernet $FTD_IF description 'Net2 - To Cisco FTD'

# ------------------------------------------------------------------------------
# 3. STATIC ROUTES (CRITICAL FOR TOPOLOGY)
# ------------------------------------------------------------------------------
# Default Route (Gateway of Last Resort - Update if Core Gateway is different!)
set protocols static route 0.0.0.0/0 next-hop 172.31.${WAN_OCTET}.1

# Route to Linux Subnet via Palo Alto
set protocols static route $LINUX_SUBNET next-hop $PA_LINK_IP

# Route to Windows Subnet via Cisco FTD
set protocols static route $WIN_SUBNET next-hop $FTD_LINK_IP

# ------------------------------------------------------------------------------
# 4. NAT (1:1 Mappings)
# ------------------------------------------------------------------------------

# --- Source NAT (Outbound for Internal Networks) ---
set nat source rule 100 outbound-interface '$WAN_IF'
set nat source rule 100 source address '$LINUX_SUBNET'
set nat source rule 100 translation address 'masquerade'

set nat source rule 110 outbound-interface '$WAN_IF'
set nat source rule 110 source address '$WIN_SUBNET'
set nat source rule 110 translation address 'masquerade'

# --- Destination NAT (Public IP -> Internal Server) ---

# Ecom (Public .11 -> Private .30)
set nat destination rule 10 description 'Ecom 1:1 NAT'
set nat destination rule 10 destination address '${PUBLIC_POOL_PREFIX}.11'
set nat destination rule 10 inbound-interface '$WAN_IF'
set nat destination rule 10 translation address '$ECOM_Inside_IP'

# Webmail (Public .39 -> Private .40)
set nat destination rule 20 description 'Webmail 1:1 NAT'
set nat destination rule 20 destination address '${PUBLIC_POOL_PREFIX}.39'
set nat destination rule 20 inbound-interface '$WAN_IF'
set nat destination rule 20 translation address '$WEBMAIL_Inside_IP'

# Splunk (Public .9 -> Private .20)
set nat destination rule 30 description 'Splunk 1:1 NAT'
set nat destination rule 30 destination address '${PUBLIC_POOL_PREFIX}.9'
set nat destination rule 30 inbound-interface '$WAN_IF'
set nat destination rule 30 translation address '$SPLUNK_Inside_IP'

# AD/DNS (Public .155 -> Private .102)
set nat destination rule 40 description 'AD DNS 1:1 NAT'
set nat destination rule 40 destination address '${PUBLIC_POOL_PREFIX}.155'
set nat destination rule 40 inbound-interface '$WAN_IF'
set nat destination rule 40 translation address '$AD_Inside_IP'

# ------------------------------------------------------------------------------
# 5. FIREWALL POLICIES (Zone Based)
# ------------------------------------------------------------------------------

# Define Networks
set firewall group network-group NET-LINUX-INSIDE network '$LINUX_SUBNET'
set firewall group network-group NET-WIN-INSIDE network '$WIN_SUBNET'
set firewall group address-group NET-PA-LINK address '172.16.101.0/24'
set firewall group address-group NET-FTD-LINK address '172.16.102.0/24'

# --- WAN IN (Protection) ---
set firewall name WAN-IN default-action 'drop'
set firewall name WAN-IN rule 10 action 'accept'
set firewall name WAN-IN rule 10 state established 'enable'
set firewall name WAN-IN rule 10 state related 'enable'

# Allow NATted Traffic (DNAT happens before Firewall)
# We accept traffic destined to Internal IPs if it matches our services
set firewall name WAN-IN rule 20 action 'accept'
set firewall name WAN-IN rule 20 destination address '$ECOM_Inside_IP'
set firewall name WAN-IN rule 20 destination port '80,443'
set firewall name WAN-IN rule 20 protocol 'tcp'
set firewall name WAN-IN rule 20 description 'Allow Web to Ecom'

set firewall name WAN-IN rule 30 action 'accept'
set firewall name WAN-IN rule 30 destination address '$WEBMAIL_Inside_IP'
set firewall name WAN-IN rule 30 destination port '25,80,443,110,143'
set firewall name WAN-IN rule 30 protocol 'tcp'
set firewall name WAN-IN rule 30 description 'Allow Mail to Webmail'

set firewall name WAN-IN rule 40 action 'accept'
set firewall name WAN-IN rule 40 protocol 'icmp'
set firewall name WAN-IN rule 40 limit rate '5/minute'

# Apply Firewall to WAN Interface
set interfaces ethernet $WAN_IF firewall in name 'WAN-IN'
set interfaces ethernet $WAN_IF firewall local name 'WAN-IN' 

# ------------------------------------------------------------------------------
# 6. LOGGING (To Splunk)
# ------------------------------------------------------------------------------
set system syslog host $SPLUNK_Inside_IP facility all level info

# ------------------------------------------------------------------------------
# 7. COMMIT & SAVE
# ------------------------------------------------------------------------------
# commit
# save
EOF

echo -e "${GREEN}[✓] Configuration generated: $OUTPUT_FILE${NC}"
echo -e "${YELLOW}Instructions:${NC}"
echo "1. Verify the Interface assignments (eth0=WAN, eth1=PA, eth2=FTD?)"
echo "2. Copy content of $OUTPUT_FILE"
echo "3. Application: ssh vyos@172.16.101.1 -> configure -> paste -> commit"
