# ==============================================================================
# SCRIPT: deploy.ps1
# PURPOSE: Main deployment script for Windows Server 2022 FTP hardening
# USAGE: .\deploy.ps1 [-DryRun] [-SkipFirewall] [-SkipSplunk] [-SkipFTP]
# ==============================================================================

param(
    [switch]$DryRun,
    [switch]$SkipFirewall,
    [switch]$SkipSplunk,
    [switch]$SkipFTP,
    [switch]$SkipAudit,
    [switch]$NonInteractive
)

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load configuration and common functions
. "$ScriptDir\vars.ps1"
. "$ScriptDir\..\common\Common-Functions.ps1"

# Override settings from params
if ($DryRun) { $script:DryRun = $true }
if ($NonInteractive) { $script:Interactive = $false }

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

Require-Administrator

Show-CCDCBanner -Version "2.0" -MachineName "FTP Server (2022)"

Write-Header "Starting FTP Server Hardening"

# Create directories
if (-not $script:DryRun) {
    New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:FTPRoot -Force | Out-Null
}

# ------------------------------------------------------------------------------
# PHASE 1: FIREWALL CONFIGURATION
# ------------------------------------------------------------------------------

if (-not $SkipFirewall) {
    Write-Header "Phase 1: Firewall Configuration"
    
    # Backup current firewall rules
    Write-Info "Backing up current firewall rules..."
    $backupFile = Backup-FirewallRules -BackupPath "$script:BackupDir\Firewall"
    
    if ($script:DryRun) {
        Write-Info "[DRY-RUN] Would configure FTP server firewall rules"
    } else {
        # Enable Windows Firewall
        Write-Info "Enabling Windows Firewall on all profiles..."
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        
        # Set default policies
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
        
        Write-Success "Firewall enabled with default deny inbound."
        
        # Add FTP specific rules
        Write-Info "Adding FTP server rules..."
        
        # FTP Control (21)
        Add-FirewallRule -DisplayName "CCDC-FTP-Control" `
                        -Direction "Inbound" `
                        -Action "Allow" `
                        -Protocol "TCP" `
                        -LocalPort 21
        
        # FTP Data (20)
        Add-FirewallRule -DisplayName "CCDC-FTP-Data" `
                        -Direction "Inbound" `
                        -Action "Allow" `
                        -Protocol "TCP" `
                        -LocalPort 20
        
        # FTP Passive Mode Range
        Write-Info "Configuring passive FTP port range..."
        Remove-NetFirewallRule -DisplayName "CCDC-FTP-Passive" -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "CCDC-FTP-Passive" `
                           -Direction Inbound `
                           -Protocol TCP `
                           -LocalPort 49152-49252 `
                           -Action Allow | Out-Null
        
        # FTPS (990)
        Add-FirewallRule -DisplayName "CCDC-FTPS" `
                        -Direction "Inbound" `
                        -Action "Allow" `
                        -Protocol "TCP" `
                        -LocalPort 990
        
        # RDP
        Add-FirewallRule -DisplayName "CCDC-RDP" `
                        -Direction "Inbound" `
                        -Action "Allow" `
                        -Protocol "TCP" `
                        -LocalPort 3389
        
        # WinRM
        Add-FirewallRule -DisplayName "CCDC-WinRM-HTTP" `
                        -Direction "Inbound" `
                        -Action "Allow" `
                        -Protocol "TCP" `
                        -LocalPort 5985
        
        # Allow ICMP (ping) for scoring
        Write-Info "Allowing ICMP for scoring..."
        Remove-NetFirewallRule -DisplayName "CCDC-ICMP-Allow" -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "CCDC-ICMP-Allow" `
                           -Protocol ICMPv4 `
                           -IcmpType 8 `
                           -Direction Inbound `
                           -Action Allow | Out-Null
        
        Write-Success "Firewall rules configured for FTP server."
    }
}

# ------------------------------------------------------------------------------
# PHASE 2: FTP SERVICE HARDENING
# ------------------------------------------------------------------------------

if (-not $SkipFTP) {
    Write-Header "Phase 2: FTP Security Hardening"
    
    # Check if FTP is installed
    $ftpInstalled = Get-Service -Name FTPSVC -ErrorAction SilentlyContinue
    
    if (-not $ftpInstalled) {
        Write-Warning "FTP Service (FTPSVC) not found."
        Write-Info "Install FTP using: Install-WindowsFeature Web-FTP-Server"
    } else {
        if ($script:DryRun) {
            Write-Info "[DRY-RUN] Would apply FTP security hardening"
        } else {
            Import-Module WebAdministration -ErrorAction SilentlyContinue
            
            # Configure FTP SSL Settings
            if ($script:FTPSettings.RequireSSL) {
                Write-Info "Configuring FTP SSL settings..."
                try {
                    # Set FTP SSL policy to require SSL
                    Set-WebConfigurationProperty -Filter /system.ftpServer/security/ssl `
                        -Name controlChannelPolicy -Value "SslRequire" `
                        -PSPath "IIS:\" -ErrorAction SilentlyContinue
                    Set-WebConfigurationProperty -Filter /system.ftpServer/security/ssl `
                        -Name dataChannelPolicy -Value "SslRequire" `
                        -PSPath "IIS:\" -ErrorAction SilentlyContinue
                    Write-Success "FTP SSL policy configured."
                } catch {
                    Write-Warning "Could not configure FTP SSL: $_"
                }
            }
            
            # Disable Anonymous Authentication
            if (-not $script:FTPSettings.AllowAnonymous) {
                Write-Info "Disabling anonymous FTP access..."
                try {
                    Set-WebConfigurationProperty -Filter /system.ftpServer/security/authentication/anonymousAuthentication `
                        -Name enabled -Value $false `
                        -PSPath "IIS:\" -ErrorAction SilentlyContinue
                    Write-Success "Anonymous FTP access disabled."
                } catch {
                    Write-Warning "Could not disable anonymous access: $_"
                }
            }
            
            # Enable Basic Authentication
            Write-Info "Enabling basic authentication..."
            try {
                Set-WebConfigurationProperty -Filter /system.ftpServer/security/authentication/basicAuthentication `
                    -Name enabled -Value $true `
                    -PSPath "IIS:\" -ErrorAction SilentlyContinue
                Write-Success "Basic authentication enabled."
            } catch {
                Write-Warning "Could not enable basic authentication: $_"
            }
            
            # Configure Passive Port Range
            Write-Info "Configuring passive FTP port range..."
            try {
                $portMin = $script:FTPSettings.PassivePortMin
                $portMax = $script:FTPSettings.PassivePortMax
                
                # Set in FTP Firewall Support
                Set-WebConfigurationProperty -Filter /system.ftpServer/firewallSupport `
                    -Name lowDataChannelPort -Value $portMin `
                    -PSPath "IIS:\" -ErrorAction SilentlyContinue
                Set-WebConfigurationProperty -Filter /system.ftpServer/firewallSupport `
                    -Name highDataChannelPort -Value $portMax `
                    -PSPath "IIS:\" -ErrorAction SilentlyContinue
                    
                Write-Success "Passive port range configured: $portMin - $portMax"
            } catch {
                Write-Warning "Could not configure passive port range: $_"
            }
            
            # Set FTP Directory Permissions
            Write-Info "Setting FTP directory permissions..."
            if (Test-Path $script:FTPRoot) {
                try {
                    $acl = Get-Acl $script:FTPRoot
                    # Remove inherited permissions
                    $acl.SetAccessRuleProtection($true, $false)
                    
                    # Add Administrators full control
                    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        "Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
                    )
                    $acl.AddAccessRule($adminRule)
                    
                    # Add SYSTEM full control
                    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        "SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
                    )
                    $acl.AddAccessRule($systemRule)
                    
                    Set-Acl -Path $script:FTPRoot -AclObject $acl
                    Write-Success "FTP directory permissions configured."
                } catch {
                    Write-Warning "Could not set FTP directory permissions: $_"
                }
            }
        }
    }
}

# ------------------------------------------------------------------------------
# PHASE 3: SERVICE HARDENING
# ------------------------------------------------------------------------------

Write-Header "Phase 3: Service Hardening"

# Ensure critical services are running
Write-Info "Verifying critical FTP services..."
foreach ($svc in $script:ProtectedServices) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.Status -ne "Running") {
            if (-not $script:DryRun) {
                Start-Service -Name $svc -ErrorAction SilentlyContinue
            }
            Write-Warning "Started service: $svc"
        } else {
            Write-Success "Service running: $svc"
        }
    }
}

# Disable dangerous services
Disable-DangerousServices -Services $script:DangerousServices -DryRun:$script:DryRun

# ------------------------------------------------------------------------------
# PHASE 4: AUDIT POLICY
# ------------------------------------------------------------------------------

if (-not $SkipAudit) {
    Write-Header "Phase 4: Audit Policy Configuration"
    Enable-AuditPolicy -DryRun:$script:DryRun
}

# ------------------------------------------------------------------------------
# PHASE 5: PASSWORD POLICY
# ------------------------------------------------------------------------------

Write-Header "Phase 5: Password Policy"
Set-StrongPasswordPolicy -DryRun:$script:DryRun

# ------------------------------------------------------------------------------
# PHASE 6: SPLUNK LOG FORWARDING
# ------------------------------------------------------------------------------

if (-not $SkipSplunk) {
    Write-Header "Phase 6: Splunk Log Forwarding"
    Setup-SplunkForwarding -SplunkServerIP $script:SplunkServerIP `
                           -SplunkPort $script:SplunkPort `
                           -DryRun:$script:DryRun
    
    # Additional: FTP log forwarding note
    Write-Info "FTP logs location: $script:FTPLogDir"
    Write-Info "Configure Splunk to monitor: $script:FTPLogDir"
}

# ------------------------------------------------------------------------------
# PHASE 7: ADDITIONAL SECURITY
# ------------------------------------------------------------------------------

Write-Header "Phase 7: Additional Security"

if (-not $script:DryRun) {
    # Disable SMBv1
    Write-Info "Disabling SMBv1..."
    try {
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
        Write-Success "SMBv1 disabled."
    } catch {
        Write-Warning "Could not disable SMBv1: $_"
    }
    
    # Disable TLS 1.0 and 1.1
    Write-Info "Disabling TLS 1.0 and 1.1..."
    try {
        $protocols = @("TLS 1.0", "TLS 1.1")
        foreach ($protocol in $protocols) {
            $serverPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Server"
            $clientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\Client"
            
            foreach ($path in @($serverPath, $clientPath)) {
                if (-not (Test-Path $path)) {
                    New-Item -Path $path -Force | Out-Null
                }
                Set-ItemProperty -Path $path -Name "Enabled" -Value 0 -Type DWord
                Set-ItemProperty -Path $path -Name "DisabledByDefault" -Value 1 -Type DWord
            }
        }
        Write-Success "TLS 1.0 and 1.1 disabled."
    } catch {
        Write-Warning "Could not disable old TLS versions: $_"
    }
} else {
    Write-Info "[DRY-RUN] Would disable SMBv1, TLS 1.0/1.1"
}

# ------------------------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------------------------

Write-Header "Deployment Complete"

$mode = if ($script:DryRun) { "DRY-RUN" } else { "LIVE" }
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    DEPLOYMENT SUMMARY                        ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║  Mode: $($mode.PadRight(51))║" -ForegroundColor Green
Write-Host "║  Machine: FTP Server (Windows Server 2022)                   ║" -ForegroundColor Green
Write-Host "║  Ports: 21 (FTP), 20 (Data), 990 (FTPS)                      ║" -ForegroundColor Green
Write-Host "║  Passive Range: 49152-49252                                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test FTP connection: ftp localhost" -ForegroundColor White
Write-Host "  2. Configure SSL certificate for FTPS" -ForegroundColor White
Write-Host "  3. Create FTP users and set permissions" -ForegroundColor White
Write-Host "  4. Review FTP logs: $script:FTPLogDir" -ForegroundColor White
Write-Host ""
