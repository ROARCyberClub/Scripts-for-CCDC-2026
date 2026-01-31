# ==============================================================================
# SCRIPT: deploy.ps1
# PURPOSE: Main deployment script for Windows 11 Workstation hardening
# USAGE: .\deploy.ps1 [-DryRun] [-SkipFirewall] [-SkipSplunk]
# ==============================================================================

param(
    [switch]$DryRun,
    [switch]$SkipFirewall,
    [switch]$SkipSplunk,
    [switch]$SkipAudit,
    [switch]$SkipPrivacy,
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

Show-CCDCBanner -Version "2.0" -MachineName "Windows 11 Workstation"

Write-Header "Starting Windows 11 Workstation Hardening"

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
        Write-Info "[DRY-RUN] Would configure workstation firewall rules"
    } else {
        # Enable Windows Firewall
        Write-Info "Enabling Windows Firewall on all profiles..."
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        
        # Set default policies - STRICT for workstation
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
        
        # Block all inbound on Public profile
        Set-NetFirewallProfile -Profile Public -AllowInboundRules False
        
        Write-Success "Firewall enabled with strict inbound blocking."
        
        # Add minimal inbound rules (only RDP for management)
        Write-Info "Adding minimal inbound rules..."
        
        foreach ($ruleName in $script:AllowedPorts.Keys) {
            $rule = $script:AllowedPorts[$ruleName]
            $port = $rule.Port
            $protocol = $rule.Protocol
            
            # Only allow from trusted IPs
            Add-FirewallRule -DisplayName "CCDC-$ruleName" `
                            -Direction "Inbound" `
                            -Action "Allow" `
                            -Protocol $protocol `
                            -LocalPort $port `
                            -RemoteAddress $script:TrustedIPs `
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
        
        # Disable common unnecessary inbound rules
        Write-Info "Disabling unnecessary inbound rules..."
        $rulesToDisable = @(
            "*File and Printer Sharing*",
            "*Network Discovery*",
            "*Remote Desktop*UDP*",
            "*mDNS*",
            "*Cast to Device*",
            "*AllJoyn*",
            "*Delivery Optimization*",
            "*Microsoft Edge*",
            "*Xbox*"
        )
        
        foreach ($pattern in $rulesToDisable) {
            Get-NetFirewallRule -DisplayName $pattern -ErrorAction SilentlyContinue | 
                Where-Object { $_.Direction -eq "Inbound" } |
                Disable-NetFirewallRule -ErrorAction SilentlyContinue
        }
        
        Write-Success "Firewall rules configured for workstation."
    }
}

# ------------------------------------------------------------------------------
# PHASE 2: WINDOWS DEFENDER
# ------------------------------------------------------------------------------

Write-Header "Phase 2: Windows Defender Configuration"

if ($script:Win11Settings.EnableDefender) {
    if ($script:DryRun) {
        Write-Info "[DRY-RUN] Would configure Windows Defender"
    } else {
        Write-Info "Configuring Windows Defender..."
        
        try {
            # Enable real-time protection
            Set-MpPreference -DisableRealtimeMonitoring $false
            Write-Success "Real-time protection enabled."
            
            # Enable cloud protection
            Set-MpPreference -MAPSReporting Advanced
            Set-MpPreference -SubmitSamplesConsent SendAllSamples
            Write-Success "Cloud protection enabled."
            
            # Enable PUA protection
            Set-MpPreference -PUAProtection Enabled
            Write-Success "PUA protection enabled."
            
            # Enable network protection
            Set-MpPreference -EnableNetworkProtection Enabled
            Write-Success "Network protection enabled."
            
            # Enable controlled folder access
            Set-MpPreference -EnableControlledFolderAccess Enabled
            Write-Success "Controlled folder access enabled."
            
            # Update definitions
            Write-Info "Updating Defender definitions..."
            Update-MpSignature -ErrorAction SilentlyContinue
            Write-Success "Defender definitions updated."
            
        } catch {
            Write-Warning "Could not configure all Defender settings: $_"
        }
    }
}

# ------------------------------------------------------------------------------
# PHASE 3: SERVICE HARDENING
# ------------------------------------------------------------------------------

Write-Header "Phase 3: Service Hardening"

# Ensure critical services are running
Write-Info "Verifying critical services..."
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
# PHASE 4: PRIVACY & TELEMETRY
# ------------------------------------------------------------------------------

if (-not $SkipPrivacy) {
    Write-Header "Phase 4: Privacy & Telemetry Settings"
    
    if ($script:DryRun) {
        Write-Info "[DRY-RUN] Would disable telemetry and privacy invasive features"
    } else {
        # Disable Telemetry
        if ($script:Win11Settings.DisableTelemetry) {
            Write-Info "Disabling Windows Telemetry..."
            try {
                $telemetryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
                if (-not (Test-Path $telemetryPath)) {
                    New-Item -Path $telemetryPath -Force | Out-Null
                }
                Set-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -Value 0 -Type DWord
                
                # Disable DiagTrack service
                Stop-Service -Name DiagTrack -Force -ErrorAction SilentlyContinue
                Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
                
                Write-Success "Windows Telemetry disabled."
            } catch {
                Write-Warning "Could not disable telemetry: $_"
            }
        }
        
        # Disable Cortana
        if ($script:Win11Settings.DisableCortana) {
            Write-Info "Disabling Cortana..."
            try {
                $cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
                if (-not (Test-Path $cortanaPath)) {
                    New-Item -Path $cortanaPath -Force | Out-Null
                }
                Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord
                Write-Success "Cortana disabled."
            } catch {
                Write-Warning "Could not disable Cortana: $_"
            }
        }
        
        # Disable Game Bar / DVR
        if ($script:Win11Settings.DisableGameBar) {
            Write-Info "Disabling Xbox Game Bar..."
            try {
                $gameDVRPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
                if (-not (Test-Path $gameDVRPath)) {
                    New-Item -Path $gameDVRPath -Force | Out-Null
                }
                Set-ItemProperty -Path $gameDVRPath -Name "AllowGameDVR" -Value 0 -Type DWord
                
                $gameBarPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
                if (-not (Test-Path $gameBarPath)) {
                    New-Item -Path $gameBarPath -Force | Out-Null
                }
                Set-ItemProperty -Path $gameBarPath -Name "AppCaptureEnabled" -Value 0 -Type DWord
                
                Write-Success "Xbox Game Bar disabled."
            } catch {
                Write-Warning "Could not disable Game Bar: $_"
            }
        }
        
        # Disable Activity History
        Write-Info "Disabling Activity History..."
        try {
            $activityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
            if (-not (Test-Path $activityPath)) {
                New-Item -Path $activityPath -Force | Out-Null
            }
            Set-ItemProperty -Path $activityPath -Name "EnableActivityFeed" -Value 0 -Type DWord
            Set-ItemProperty -Path $activityPath -Name "PublishUserActivities" -Value 0 -Type DWord
            Set-ItemProperty -Path $activityPath -Name "UploadUserActivities" -Value 0 -Type DWord
            Write-Success "Activity History disabled."
        } catch {
            Write-Warning "Could not disable Activity History: $_"
        }
    }
}

# ------------------------------------------------------------------------------
# PHASE 5: AUDIT POLICY
# ------------------------------------------------------------------------------

if (-not $SkipAudit) {
    Write-Header "Phase 5: Audit Policy Configuration"
    Enable-AuditPolicy -DryRun:$script:DryRun
}

# ------------------------------------------------------------------------------
# PHASE 6: PASSWORD POLICY
# ------------------------------------------------------------------------------

Write-Header "Phase 6: Password Policy"
Set-StrongPasswordPolicy -DryRun:$script:DryRun

# ------------------------------------------------------------------------------
# PHASE 7: SPLUNK LOG FORWARDING
# ------------------------------------------------------------------------------

if (-not $SkipSplunk) {
    Write-Header "Phase 7: Splunk Log Forwarding"
    Setup-SplunkForwarding -SplunkServerIP $script:SplunkServerIP `
                           -SplunkPort $script:SplunkPort `
                           -DryRun:$script:DryRun
}

# ------------------------------------------------------------------------------
# PHASE 8: ADDITIONAL SECURITY
# ------------------------------------------------------------------------------

Write-Header "Phase 8: Additional Security Hardening"

if (-not $script:DryRun) {
    # Disable SMBv1
    Write-Info "Disabling SMBv1..."
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Success "SMBv1 disabled."
    } catch {
        Write-Warning "Could not disable SMBv1: $_"
    }
    
    # Disable Remote Assistance
    Write-Info "Disabling Remote Assistance..."
    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 0 -Type DWord
        Write-Success "Remote Assistance disabled."
    } catch {
        Write-Warning "Could not disable Remote Assistance: $_"
    }
    
    # Disable AutoPlay
    Write-Info "Disabling AutoPlay..."
    try {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord
        Write-Success "AutoPlay disabled."
    } catch {
        Write-Warning "Could not disable AutoPlay: $_"
    }
    
    # Enable UAC
    Write-Info "Ensuring UAC is enabled..."
    try {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1 -Type DWord
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 2 -Type DWord
        Write-Success "UAC enabled and configured."
    } catch {
        Write-Warning "Could not configure UAC: $_"
    }
    
    # Disable Guest Account
    Write-Info "Disabling Guest account..."
    try {
        Disable-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
        Write-Success "Guest account disabled."
    } catch {
        Write-Warning "Could not disable Guest account: $_"
    }
    
    # Require Ctrl+Alt+Del for login
    Write-Info "Requiring Ctrl+Alt+Del for login..."
    try {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableCAD" -Value 0 -Type DWord
        Write-Success "Ctrl+Alt+Del required for login."
    } catch {
        Write-Warning "Could not configure login requirement: $_"
    }
    
} else {
    Write-Info "[DRY-RUN] Would apply additional security hardening"
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
Write-Host "║  Machine: Windows 11 Workstation                             ║" -ForegroundColor Green
Write-Host "║  Inbound: RDP (3389) from trusted IPs only                   ║" -ForegroundColor Green
Write-Host "║  Defender: Enabled with advanced protection                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if ($backupFile) {
    Write-Info "Firewall backup saved to: $backupFile"
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Verify domain connectivity if domain-joined" -ForegroundColor White
Write-Host "  2. Run Windows Update for security patches" -ForegroundColor White
Write-Host "  3. Review installed applications for vulnerabilities" -ForegroundColor White
Write-Host "  4. Consider enabling BitLocker for drive encryption" -ForegroundColor White
Write-Host ""
