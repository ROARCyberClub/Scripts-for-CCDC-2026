# ==============================================================================
# SCRIPT: vars.ps1
# PURPOSE: Configuration variables for Windows Server 2019 Web (IIS)
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
# 3. WEB SERVER SPECIFIC PORTS
# ------------------------------------------------------------------------------
$script:AllowedPorts = @{
    # HTTP/HTTPS
    "HTTP" = @{ Protocol = "TCP"; Port = 80 }
    "HTTPS" = @{ Protocol = "TCP"; Port = 443 }
    
    # RDP (for management - restrict to trusted IPs)
    "RDP" = @{ Protocol = "TCP"; Port = 3389 }
    
    # WinRM (for management)
    "WinRM-HTTP" = @{ Protocol = "TCP"; Port = 5985 }
    "WinRM-HTTPS" = @{ Protocol = "TCP"; Port = 5986 }
}

# ------------------------------------------------------------------------------
# 4. PROTECTED SERVICES
# ------------------------------------------------------------------------------
$script:ProtectedServices = @(
    "W3SVC",              # IIS World Wide Web Publishing Service
    "WAS",                # Windows Process Activation Service
    "IISADMIN",           # IIS Admin Service
    "EventLog",
    "WinRM",
    "W32Time"
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
    "FTP",                # FTP is on separate server
    "FTPSVC"
)

# ------------------------------------------------------------------------------
# 6. PROTECTED USERS (DO NOT LOCK/DELETE)
# ------------------------------------------------------------------------------
$script:ProtectedUsers = @(
    "Administrator",
    "DefaultAccount",
    "WDAGUtilityAccount",
    "IUSR",               # IIS Anonymous User
    "IIS_IUSRS"           # IIS Users Group
)

# ------------------------------------------------------------------------------
# 7. LOGGING
# ------------------------------------------------------------------------------
$script:LogDir = "C:\CCDC\Logs"
$script:BackupDir = "C:\CCDC\Backups"
$script:IISLogDir = "C:\inetpub\logs\LogFiles"

# ------------------------------------------------------------------------------
# 8. IIS SECURITY SETTINGS
# ------------------------------------------------------------------------------
$script:IISSettings = @{
    RemoveServerHeader = $true
    DisableDirectoryBrowsing = $true
    EnableRequestFiltering = $true
    MaxAllowedContentLength = 30000000   # 30MB
    MaxUrl = 4096
    MaxQueryString = 2048
}

# ------------------------------------------------------------------------------
# 9. SECURITY SETTINGS
# ------------------------------------------------------------------------------
$script:LockoutThreshold = 5
$script:LockoutDuration = 30
$script:MinPasswordLength = 12
$script:MaxPasswordAge = 90
