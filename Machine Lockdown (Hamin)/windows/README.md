# Windows CCDC Defense Scripts

PowerShell scripts for hardening Windows machines and forwarding logs to Splunk.

## Target Machines

| Machine | OS | Role | Inbound Ports |
|---------|-----|------|---------------|
| AD/DNS | Windows Server 2019 | Active Directory, DNS | 53, 88, 135, 389, 445, 636, 3268, 3389 |
| Web | Windows Server 2019 | IIS Web Server | 80, 443, 3389 |
| FTP | Windows Server 2022 | FTP Server | 20, 21, 990, 49152-49252 (passive) |
| Workstation | Windows 11 | Client | 3389 (from trusted IPs only) |

## Directory Structure

```
windows/
├── common/
│   └── Common-Functions.ps1    # Shared functions for all scripts
├── ad-dns/
│   ├── vars.ps1                # AD/DNS configuration
│   └── deploy.ps1              # AD/DNS deployment script
├── web/
│   ├── vars.ps1                # Web server configuration
│   └── deploy.ps1              # Web deployment script
├── ftp/
│   ├── vars.ps1                # FTP configuration
│   └── deploy.ps1              # FTP deployment script
├── workstation/
│   ├── vars.ps1                # Workstation configuration
│   └── deploy.ps1              # Workstation deployment script
└── README.md                   # This file
```

## Quick Start

### 1. Open PowerShell as Administrator

```powershell
# Right-click PowerShell -> Run as Administrator
```

### 2. Navigate to the appropriate folder

```powershell
cd "C:\path\to\windows\ad-dns"   # For AD/DNS server
cd "C:\path\to\windows\web"      # For Web server
cd "C:\path\to\windows\ftp"      # For FTP server
cd "C:\path\to\windows\workstation"  # For workstation
```

### 3. Run the deployment script

```powershell
# Dry-run first (no changes made)
.\deploy.ps1 -DryRun

# Live execution
.\deploy.ps1

# Skip specific phases
.\deploy.ps1 -SkipFirewall -SkipSplunk
```

## Splunk Log Forwarding

All scripts configure Windows Event Forwarding to send logs to the Splunk server.

**Splunk Server:** `172.20.242.20:514` (UDP Syslog)

### How it works:

1. **NXLog Method** (if installed):
   - Configures NXLog to forward Security, System, and Application logs
   - Uses UDP 514 (syslog) to Splunk server

2. **Windows Event Forwarding** (fallback):
   - Enables WinRM service
   - Configures Windows Event Collector
   - Note: Splunk Universal Forwarder is recommended for best results

### Recommended: Install Splunk Universal Forwarder

1. Download from: https://www.splunk.com/en_us/download/universal-forwarder.html
2. Install with:
   ```cmd
   msiexec.exe /i splunkforwarder.msi RECEIVING_INDEXER="172.20.242.20:9997" WINEVENTLOG_APP_ENABLE=1 WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 AGREETOLICENSE=yes /quiet
   ```

## Script Features

### Common Features (all scripts)
- ✅ Windows Firewall configuration with default deny
- ✅ Audit policy enabling for all security events
- ✅ Strong password policy enforcement
- ✅ Dangerous service disabling
- ✅ SMBv1 disabling
- ✅ Splunk log forwarding setup
- ✅ Backup and rollback support

### AD/DNS Specific
- ✅ AD service port configuration (DNS, Kerberos, LDAP, etc.)
- ✅ LLMNR disabling
- ✅ NetBIOS over TCP/IP disabling
- ✅ SMB signing requirement

### Web Server (IIS) Specific
- ✅ IIS security hardening
- ✅ Dangerous HTTP verb disabling (TRACE, TRACK, DEBUG)
- ✅ Directory browsing disabling
- ✅ TLS 1.0/1.1 disabling, TLS 1.2 enabling
- ✅ Request filtering configuration

### FTP Server Specific
- ✅ FTP SSL/FTPS configuration
- ✅ Anonymous access disabling
- ✅ Passive mode port range configuration
- ✅ FTP directory permission hardening

### Windows 11 Workstation Specific
- ✅ Windows Defender advanced configuration
- ✅ Telemetry/privacy feature disabling
- ✅ Strict inbound firewall (RDP from trusted IPs only)
- ✅ Guest account disabling
- ✅ UAC enforcement
- ✅ AutoPlay disabling

## Command Line Options

| Option | Description |
|--------|-------------|
| `-DryRun` | Preview changes without applying them |
| `-SkipFirewall` | Skip firewall configuration |
| `-SkipSplunk` | Skip Splunk log forwarding setup |
| `-SkipAudit` | Skip audit policy configuration |
| `-SkipIIS` | (Web only) Skip IIS hardening |
| `-SkipFTP` | (FTP only) Skip FTP service hardening |
| `-SkipPrivacy` | (Workstation only) Skip privacy settings |
| `-NonInteractive` | Run without user prompts |

## Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                     CCDC Network (172.20.x.x)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   AD/DNS     │    │  Web Server  │    │  FTP Server  │       │
│  │ 172.20.240.x │    │ 172.20.241.x │    │ 172.20.241.x │       │
│  │   (2019)     │    │    (2019)    │    │    (2022)    │       │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘       │
│         │                   │                   │                │
│         └───────────────────┼───────────────────┘                │
│                             │                                    │
│                    ┌────────┴────────┐                          │
│                    │  Palo Alto FW   │                          │
│                    │  172.20.242.254 │                          │
│                    └────────┬────────┘                          │
│                             │                                    │
│         ┌───────────────────┼───────────────────┐               │
│         │                   │                   │                │
│  ┌──────┴───────┐    ┌──────┴───────┐    ┌──────┴───────┐       │
│  │   Splunk     │    │  Workstation │    │   Linux VMs  │       │
│  │ 172.20.242.20│    │   Win 11     │    │  (Ubuntu/Fed)│       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Rollback

Firewall rules are automatically backed up before changes:

```powershell
# List backups
dir C:\CCDC\Backups\Firewall

# Restore firewall
netsh advfirewall import "C:\CCDC\Backups\Firewall\firewall_backup_YYYYMMDD_HHMMSS.wfw"
```

## Troubleshooting

### Script won't run
```powershell
# Set execution policy (run as admin)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### Firewall blocking legitimate traffic
```powershell
# View CCDC rules
Get-NetFirewallRule -DisplayName "CCDC-*" | Format-Table Name, Enabled, Direction, Action

# Disable a specific rule
Disable-NetFirewallRule -DisplayName "CCDC-RuleName"

# Restore from backup
netsh advfirewall import "path\to\backup.wfw"
```

### Check Splunk connectivity
```powershell
# Test UDP 514 to Splunk
Test-NetConnection -ComputerName 172.20.242.20 -Port 514

# Check WinRM status
Get-Service WinRM
winrm enumerate winrm/config/listener
```

## Author

Created for CCDC 2026 Competition
