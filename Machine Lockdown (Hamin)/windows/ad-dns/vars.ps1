# ==============================================================================
# SCRIPT: vars.ps1
# PURPOSE: Configuration variables for Windows Server 2019 AD/DNS
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

# Scoreboard IPs that must always be allowed
$script:ScoreboardIPs = @(
    "10.0.0.1"
)

# Trusted management IPs
$script:TrustedIPs = @(
    "172.20.240.0/24",    # Internal management
    "172.20.241.0/24",
    "172.20.242.0/24"
)

# ------------------------------------------------------------------------------
# 3. AD/DNS SPECIFIC PORTS
# ------------------------------------------------------------------------------
$script:AllowedPorts = @{
    # DNS
    "DNS-TCP" = @{ Protocol = "TCP"; Port = 53 }
    "DNS-UDP" = @{ Protocol = "UDP"; Port = 53 }
    
    # Kerberos
    "Kerberos-TCP" = @{ Protocol = "TCP"; Port = 88 }
    "Kerberos-UDP" = @{ Protocol = "UDP"; Port = 88 }
    
    # RPC/LDAP
    "RPC-Endpoint" = @{ Protocol = "TCP"; Port = 135 }
    "NetBIOS-Name" = @{ Protocol = "UDP"; Port = 137 }
    "NetBIOS-Datagram" = @{ Protocol = "UDP"; Port = 138 }
    "NetBIOS-Session" = @{ Protocol = "TCP"; Port = 139 }
    "LDAP-TCP" = @{ Protocol = "TCP"; Port = 389 }
    "LDAP-UDP" = @{ Protocol = "UDP"; Port = 389 }
    "LDAPS" = @{ Protocol = "TCP"; Port = 636 }
    "SMB" = @{ Protocol = "TCP"; Port = 445 }
    
    # Global Catalog
    "GC" = @{ Protocol = "TCP"; Port = 3268 }
    "GC-SSL" = @{ Protocol = "TCP"; Port = 3269 }
    
    # Kerberos Password Change
    "Kerberos-Pwd" = @{ Protocol = "TCP"; Port = 464 }
    "Kerberos-Pwd-UDP" = @{ Protocol = "UDP"; Port = 464 }
    
    # RDP (for management)
    "RDP" = @{ Protocol = "TCP"; Port = 3389 }
    
    # WinRM (for management)
    "WinRM-HTTP" = @{ Protocol = "TCP"; Port = 5985 }
    "WinRM-HTTPS" = @{ Protocol = "TCP"; Port = 5986 }
    
    # NTP
    "NTP" = @{ Protocol = "UDP"; Port = 123 }
    
    # High ports for RPC dynamic
    "RPC-Dynamic" = @{ Protocol = "TCP"; Port = "49152-65535" }
}

# ------------------------------------------------------------------------------
# 4. PROTECTED SERVICES
# ------------------------------------------------------------------------------
$script:ProtectedServices = @(
    "DNS",
    "NTDS",           # Active Directory Domain Services
    "Netlogon",
    "KDC",            # Kerberos Key Distribution Center
    "W32Time",        # Windows Time
    "DFSR",           # DFS Replication
    "LanmanServer",   # SMB Server
    "LanmanWorkstation",
    "EventLog",
    "WinRM"
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
    "krbtgt",
    "DefaultAccount",
    "WDAGUtilityAccount"
)

# ------------------------------------------------------------------------------
# 7. LOGGING
# ------------------------------------------------------------------------------
$script:LogDir = "C:\CCDC\Logs"
$script:BackupDir = "C:\CCDC\Backups"

# ------------------------------------------------------------------------------
# 8. SECURITY SETTINGS
# ------------------------------------------------------------------------------
$script:LockoutThreshold = 5
$script:LockoutDuration = 30        # minutes
$script:MinPasswordLength = 12
$script:MaxPasswordAge = 90         # days
