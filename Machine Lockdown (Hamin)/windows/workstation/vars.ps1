# ==============================================================================
# SCRIPT: vars.ps1
# PURPOSE: Configuration variables for Windows 11 Workstation
# USAGE: . .\vars.ps1
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. EXECUTION MODE
# ------------------------------------------------------------------------------
$script:Interactive = $true
$script:DryRun = $false
$script:Verbose = $true

# ------------------------------------------------------------------------------
# 2. NETWORK CONFIGURATION
# ------------------------------------------------------------------------------
$script:SplunkServerIP = "172.20.242.20"
$script:SplunkPort = 514
$script:GatewayIP = "172.20.242.254"      # Palo Alto Inside
$script:AD_DNS_IP = "172.20.240.102"      # AD/DNS Server

# Scoreboard IPs that must always be allowed
$script:ScoreboardIPs = @(
    "10.0.0.1"
)

# Trusted management IPs
$script:TrustedIPs = @(
    "172.20.240.0/24",
    "172.20.241.0/24",
    "172.20.242.0/24"
)

# ------------------------------------------------------------------------------
# 3. WORKSTATION PORTS (MINIMAL)
# ------------------------------------------------------------------------------
$script:AllowedPorts = @{
    # RDP (for management - restrict to trusted IPs only)
    "RDP" = @{ Protocol = "TCP"; Port = 3389 }
    
    # WinRM (for management)
    "WinRM-HTTP" = @{ Protocol = "TCP"; Port = 5985 }
    "WinRM-HTTPS" = @{ Protocol = "TCP"; Port = 5986 }
}

# Outbound allowed (workstation needs to access services)
$script:AllowedOutbound = @{
    "DNS" = @{ Protocol = "UDP"; Port = 53 }
    "HTTP" = @{ Protocol = "TCP"; Port = 80 }
    "HTTPS" = @{ Protocol = "TCP"; Port = 443 }
    "Kerberos" = @{ Protocol = "TCP"; Port = 88 }
    "LDAP" = @{ Protocol = "TCP"; Port = 389 }
    "SMB" = @{ Protocol = "TCP"; Port = 445 }
}

# ------------------------------------------------------------------------------
# 4. PROTECTED SERVICES
# ------------------------------------------------------------------------------
$script:ProtectedServices = @(
    "EventLog",
    "WinRM",
    "W32Time",
    "Dnscache",           # DNS Client
    "Netlogon",
    "LanmanWorkstation"   # SMB Client
)

# ------------------------------------------------------------------------------
# 5. DANGEROUS SERVICES TO DISABLE
# ------------------------------------------------------------------------------
$script:DangerousServices = @(
    "RemoteRegistry",
    "Telnet",
    "TlntSvr",
    "SNMP",
    "SNMPTRAP",
    "SSDPSRV",
    "upnphost",
    "Browser",
    "lmhosts",
    "NetTcpPortSharing",
    "WMPNetworkSvc",
    "SharedAccess",       # Internet Connection Sharing
    "RemoteAccess",       # Routing and Remote Access
    "RasAuto",           # Remote Access Auto Connection
    "RasMan",            # Remote Access Connection Manager
    "XboxGipSvc",        # Xbox Game Input Protocol
    "XblAuthManager",    # Xbox Live Auth Manager
    "XblGameSave",       # Xbox Live Game Save
    "XboxNetApiSvc"      # Xbox Live Networking
)

# ------------------------------------------------------------------------------
# 6. PROTECTED USERS (DO NOT LOCK/DELETE)
# ------------------------------------------------------------------------------
$script:ProtectedUsers = @(
    "Administrator",
    "DefaultAccount",
    "WDAGUtilityAccount"
)

# ------------------------------------------------------------------------------
# 7. LOGGING
# ------------------------------------------------------------------------------
$script:LogDir = "C:\CCDC\Logs"
$script:BackupDir = "C:\CCDC\Backups"

# ------------------------------------------------------------------------------
# 8. WINDOWS 11 SPECIFIC SETTINGS
# ------------------------------------------------------------------------------
$script:Win11Settings = @{
    DisableTelemetry = $true
    DisableCortana = $true
    DisableOneDrive = $false       # May be needed for competition
    DisableGameBar = $true
    EnableBitLocker = $false       # Depends on competition requirements
    EnableDefender = $true
}

# ------------------------------------------------------------------------------
# 9. SECURITY SETTINGS
# ------------------------------------------------------------------------------
$script:LockoutThreshold = 5
$script:LockoutDuration = 30
$script:MinPasswordLength = 12
$script:MaxPasswordAge = 90
