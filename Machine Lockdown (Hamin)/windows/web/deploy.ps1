# ==============================================================================
# SCRIPT: deploy.ps1
# PURPOSE: Main deployment script for Windows Server 2019 Web (IIS) hardening
# USAGE: .\deploy.ps1 [-DryRun] [-SkipFirewall] [-SkipSplunk] [-SkipIIS]
# ==============================================================================

param(
    [switch]$DryRun,
    [switch]$SkipFirewall,
    [switch]$SkipSplunk,
    [switch]$SkipIIS,
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

Show-CCDCBanner -Version "2.0" -MachineName "Web Server (IIS 2019)"

Write-Header "Starting Web Server Hardening"

# Create directories
if (-not $script:DryRun) {
    New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
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
        Write-Info "[DRY-RUN] Would configure Web server firewall rules"
    } else {
        # Enable Windows Firewall
        Write-Info "Enabling Windows Firewall on all profiles..."
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        
        # Set default policies
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
        
        Write-Success "Firewall enabled with default deny inbound."
        
        # Add Web server specific rules
        Write-Info "Adding Web server rules..."
        
        foreach ($ruleName in $script:AllowedPorts.Keys) {
            $rule = $script:AllowedPorts[$ruleName]
            $port = $rule.Port
            $protocol = $rule.Protocol
            
            Add-FirewallRule -DisplayName "CCDC-$ruleName" `
                            -Direction "Inbound" `
                            -Action "Allow" `
                            -Protocol $protocol `
                            -LocalPort $port `
                            -DryRun:$script:DryRun
        }
        
        # Allow ICMP (ping) for scoring
        Write-Info "Allowing ICMP for scoring..."
        Remove-NetFirewallRule -DisplayName "CCDC-ICMP-Allow" -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "CCDC-ICMP-Allow" `
                           -Protocol ICMPv4 `
                           -IcmpType 8 `
                           -Direction Inbound `
                           -Action Allow | Out-Null
        
        Write-Success "Firewall rules configured for Web server."
    }
}

# ------------------------------------------------------------------------------
# PHASE 2: IIS HARDENING
# ------------------------------------------------------------------------------

if (-not $SkipIIS) {
    Write-Header "Phase 2: IIS Security Hardening"
    
    # Check if IIS is installed
    $iisInstalled = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
    
    if (-not $iisInstalled) {
        Write-Warning "IIS (W3SVC) not found. Skipping IIS hardening."
    } else {
        if ($script:DryRun) {
            Write-Info "[DRY-RUN] Would apply IIS security hardening"
        } else {
            Import-Module WebAdministration -ErrorAction SilentlyContinue
            
            # Remove Server header
            if ($script:IISSettings.RemoveServerHeader) {
                Write-Info "Removing IIS Server header..."
                try {
                    # Using URL Rewrite or applicationHost.config
                    $configPath = "$env:windir\System32\inetsrv\config\applicationHost.config"
                    if (Test-Path $configPath) {
                        Write-Success "Configure urlRewrite to remove Server header manually."
                    }
                } catch {
                    Write-Warning "Could not remove Server header: $_"
                }
            }
            
            # Disable directory browsing
            if ($script:IISSettings.DisableDirectoryBrowsing) {
                Write-Info "Disabling directory browsing..."
                try {
                    Set-WebConfigurationProperty -Filter /system.webServer/directoryBrowse `
                        -Name enabled -Value $false -PSPath "IIS:\"
                    Write-Success "Directory browsing disabled."
                } catch {
                    Write-Warning "Could not disable directory browsing: $_"
                }
            }
            
            # Enable Request Filtering
            if ($script:IISSettings.EnableRequestFiltering) {
                Write-Info "Configuring Request Filtering..."
                try {
                    # Set max content length
                    Set-WebConfigurationProperty -Filter /system.webServer/security/requestFiltering/requestLimits `
                        -Name maxAllowedContentLength `
                        -Value $script:IISSettings.MaxAllowedContentLength `
                        -PSPath "IIS:\" -ErrorAction SilentlyContinue
                    
                    Write-Success "Request filtering configured."
                } catch {
                    Write-Warning "Could not configure request filtering: $_"
                }
            }
            
            # Disable dangerous HTTP verbs
            Write-Info "Disabling dangerous HTTP verbs..."
            try {
                $dangerousVerbs = @("TRACE", "TRACK", "DEBUG", "OPTIONS")
                foreach ($verb in $dangerousVerbs) {
                    # Add verb to denied list
                    Add-WebConfigurationProperty -Filter /system.webServer/security/requestFiltering/verbs `
                        -Name "." `
                        -Value @{verb=$verb; allowed="False"} `
                        -PSPath "IIS:\" -ErrorAction SilentlyContinue
                }
                Write-Success "Dangerous HTTP verbs disabled."
            } catch {
                Write-Warning "Could not disable HTTP verbs: $_"
            }
            
            # Enable logging
            Write-Info "Configuring IIS logging..."
            try {
                Set-WebConfigurationProperty -Filter /system.applicationHost/sites/siteDefaults/logFile `
                    -Name logFormat -Value "W3C" -PSPath "IIS:\" -ErrorAction SilentlyContinue
                Write-Success "IIS logging configured."
            } catch {
                Write-Warning "Could not configure IIS logging: $_"
            }
        }
    }
}

# ------------------------------------------------------------------------------
# PHASE 3: SERVICE HARDENING
# ------------------------------------------------------------------------------

Write-Header "Phase 3: Service Hardening"

# Ensure critical services are running
Write-Info "Verifying critical Web services..."
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
    
    # Additional: IIS log forwarding note
    Write-Info "IIS logs location: $script:IISLogDir"
    Write-Info "Configure Splunk to monitor: $script:IISLogDir"
}

# ------------------------------------------------------------------------------
# PHASE 7: ADDITIONAL WEB SECURITY
# ------------------------------------------------------------------------------

Write-Header "Phase 7: Additional Web Security"

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
    
    # Enable TLS 1.2
    Write-Info "Ensuring TLS 1.2 is enabled..."
    try {
        $tls12ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
        $tls12ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"
        
        foreach ($path in @($tls12ServerPath, $tls12ClientPath)) {
            if (-not (Test-Path $path)) {
                New-Item -Path $path -Force | Out-Null
            }
            Set-ItemProperty -Path $path -Name "Enabled" -Value 1 -Type DWord
            Set-ItemProperty -Path $path -Name "DisabledByDefault" -Value 0 -Type DWord
        }
        Write-Success "TLS 1.2 enabled."
    } catch {
        Write-Warning "Could not enable TLS 1.2: $_"
    }
} else {
    Write-Info "[DRY-RUN] Would disable SMBv1, TLS 1.0/1.1 and enable TLS 1.2"
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
Write-Host "║  Machine: Web Server (Windows Server 2019 IIS)               ║" -ForegroundColor Green
Write-Host "║  Ports: 80 (HTTP), 443 (HTTPS)                               ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test website access: http://localhost and https://localhost" -ForegroundColor White
Write-Host "  2. Review IIS logs: $script:IISLogDir" -ForegroundColor White
Write-Host "  3. Configure Splunk to monitor IIS logs" -ForegroundColor White
Write-Host "  4. Consider installing URL Rewrite module for header removal" -ForegroundColor White
Write-Host ""
