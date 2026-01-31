# ==============================================================================
# SCRIPT: vars.ps1
# PURPOSE: Configuration variables for Windows Server 2022 FTP
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
# 3. FTP SERVER SPECIFIC PORTS
# ------------------------------------------------------------------------------
$script:AllowedPorts = @{
    # FTP Control
    "FTP-Control" = @{ Protocol = "TCP"; Port = 21 }
    
    # FTP Data (Active mode)
    "FTP-Data" = @{ Protocol = "TCP"; Port = 20 }
    
    # FTP Passive Mode Range (configure in IIS FTP)
    "FTP-Passive" = @{ Protocol = "TCP"; Port = "49152-49252" }
    
    # FTPS (Explicit TLS)
    "FTPS" = @{ Protocol = "TCP"; Port = 990 }
    
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
    "FTPSVC",             # FTP Service
    "W3SVC",              # IIS (if FTP uses IIS)
    "WAS",                # Windows Process Activation Service
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
    "WMPNetworkSvc"
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
$script:FTPLogDir = "C:\inetpub\logs\LogFiles"
$script:FTPRoot = "C:\FTPRoot"

# ------------------------------------------------------------------------------
# 8. FTP SECURITY SETTINGS
# ------------------------------------------------------------------------------
$script:FTPSettings = @{
    RequireSSL = $true
    AllowAnonymous = $false
    PassivePortMin = 49152
    PassivePortMax = 49252
    MaxConnections = 100
    ConnectionTimeout = 120
}

# ------------------------------------------------------------------------------
# 9. SECURITY SETTINGS
# ------------------------------------------------------------------------------
$script:LockoutThreshold = 5
$script:LockoutDuration = 30
$script:MinPasswordLength = 12
$script:MaxPasswordAge = 90
