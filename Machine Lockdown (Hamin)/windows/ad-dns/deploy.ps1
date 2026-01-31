# ==============================================================================
# SCRIPT: deploy.ps1
# PURPOSE: Main deployment script for Windows Server 2019 AD/DNS hardening
# USAGE: .\deploy.ps1 [-DryRun] [-SkipFirewall] [-SkipSplunk]
# ==============================================================================

param(
    [switch]$DryRun,
    [switch]$SkipFirewall,
    [switch]$SkipSplunk,
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

Show-CCDCBanner -Version "2.0" -MachineName "AD/DNS Server (2019)"

Write-Header "Starting AD/DNS Server Hardening"

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
        Write-Info "[DRY-RUN] Would configure AD/DNS firewall rules"
    } else {
        # Enable Windows Firewall
        Write-Info "Enabling Windows Firewall on all profiles..."
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        
        # Set default policies
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
        
        Write-Success "Firewall enabled with default deny inbound."
        
        # Add AD/DNS specific rules
        Write-Info "Adding AD/DNS service rules..."
        
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
        
        Write-Success "Firewall rules configured for AD/DNS services."
    }
}

# ------------------------------------------------------------------------------
# PHASE 2: SERVICE HARDENING
# ------------------------------------------------------------------------------

Write-Header "Phase 2: Service Hardening"

# Ensure critical AD services are running
Write-Info "Verifying critical AD/DNS services..."
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
# PHASE 3: AUDIT POLICY
# ------------------------------------------------------------------------------

if (-not $SkipAudit) {
    Write-Header "Phase 3: Audit Policy Configuration"
    Enable-AuditPolicy -DryRun:$script:DryRun
}

# ------------------------------------------------------------------------------
# PHASE 4: PASSWORD POLICY
# ------------------------------------------------------------------------------

Write-Header "Phase 4: Password Policy"
Set-StrongPasswordPolicy -DryRun:$script:DryRun

# ------------------------------------------------------------------------------
# PHASE 5: SPLUNK LOG FORWARDING
# ------------------------------------------------------------------------------

if (-not $SkipSplunk) {
    Write-Header "Phase 5: Splunk Log Forwarding"
    Setup-SplunkForwarding -SplunkServerIP $script:SplunkServerIP `
                           -SplunkPort $script:SplunkPort `
                           -DryRun:$script:DryRun
}

# ------------------------------------------------------------------------------
# PHASE 6: ADDITIONAL AD SECURITY
# ------------------------------------------------------------------------------

Write-Header "Phase 6: AD-Specific Security"

if (-not $script:DryRun) {
    # Disable LLMNR
    Write-Info "Disabling LLMNR..."
    try {
        $llmnrPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
        if (-not (Test-Path $llmnrPath)) {
            New-Item -Path $llmnrPath -Force | Out-Null
        }
        Set-ItemProperty -Path $llmnrPath -Name "EnableMulticast" -Value 0 -Type DWord
        Write-Success "LLMNR disabled."
    } catch {
        Write-Warning "Could not disable LLMNR: $_"
    }
    
    # Disable NetBIOS over TCP/IP (per adapter)
    Write-Info "Disabling NetBIOS over TCP/IP..."
    try {
        $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"
        foreach ($adapter in $adapters) {
            $adapter.SetTcpipNetbios(2) | Out-Null  # 2 = Disable
        }
        Write-Success "NetBIOS over TCP/IP disabled."
    } catch {
        Write-Warning "Could not disable NetBIOS: $_"
    }
    
    # Disable SMBv1
    Write-Info "Disabling SMBv1..."
    try {
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Success "SMBv1 disabled."
    } catch {
        Write-Warning "Could not disable SMBv1: $_"
    }
    
    # Require SMB Signing
    Write-Info "Requiring SMB Signing..."
    try {
        Set-SmbServerConfiguration -RequireSecuritySignature $true -Force
        Write-Success "SMB Signing required."
    } catch {
        Write-Warning "Could not require SMB signing: $_"
    }
} else {
    Write-Info "[DRY-RUN] Would disable LLMNR, NetBIOS, SMBv1 and require SMB signing"
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
Write-Host "║  Machine: AD/DNS Server (Windows Server 2019)                ║" -ForegroundColor Green
Write-Host "║  Firewall: $(if($SkipFirewall){"SKIPPED"}else{"CONFIGURED"})  $((" " * 40))║".Substring(0,64) -ForegroundColor Green
Write-Host "║  Splunk: $(if($SkipSplunk){"SKIPPED"}else{"$script:SplunkServerIP`:$script:SplunkPort"})  $((" " * 30))║".Substring(0,64) -ForegroundColor Green
Write-Host "║  Audit: $(if($SkipAudit){"SKIPPED"}else{"ENABLED"})  $((" " * 43))║".Substring(0,64) -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if ($backupFile) {
    Write-Info "Firewall backup saved to: $backupFile"
    Write-Info "To rollback: netsh advfirewall import `"$backupFile`""
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review firewall rules: Get-NetFirewallRule -DisplayName 'CCDC-*'" -ForegroundColor White
Write-Host "  2. Check event logs for any issues" -ForegroundColor White
Write-Host "  3. Test AD/DNS functionality from client machines" -ForegroundColor White
Write-Host "  4. Consider installing Splunk Universal Forwarder for better log collection" -ForegroundColor White
Write-Host ""
