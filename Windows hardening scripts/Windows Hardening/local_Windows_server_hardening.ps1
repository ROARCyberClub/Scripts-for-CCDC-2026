#Requires -RunAsAdministrator

# Admin Check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "CRITICAL: You are NOT running as Administrator."
    exit
}

Clear-Host
$LogPath = "C:\Temp\MWCCDC_Hardening.log"
if (!(Test-Path "C:\Temp")) { New-Item -ItemType Directory -Force -Path "C:\Temp" | Out-Null }

function Update-Log {
    param([string]$Action, [string]$Status)
    $Entry = "[$(Get-Date -Format 'HH:mm:ss')] - $Action - $Status"
    Add-Content -Path $LogPath -Value $Entry -Force
    Write-Host $Entry -ForegroundColor Cyan
}

# --- Backup ---
function Emergency-Backup {
    Write-Host "`n--- Step 1: Emergency Backup ---" -ForegroundColor Yellow
    $BackupPath = "C:\Backups_LocalHardening"
    if (!(Test-Path $BackupPath)) { New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null }
    
    try {
        netsh advfirewall export "$BackupPath\FirewallConfig.wfw"
        Get-LocalUser | Export-Csv "$BackupPath\LocalUsers.csv" -NoTypeInformation
        Update-Log "Backup" "Completed at $BackupPath"
    } catch {
        Update-Log "Backup" "FAILED: $($_.Exception.Message)"
    }
}

# --- User Management ---
function CreateAdmin {
    Write-Host "`n--- Step 2: Create NEW Local Admin User ---" -ForegroundColor Yellow
    $NewUser = Read-Host "Enter NEW Team Admin Username"
    if ([string]::IsNullOrWhiteSpace($NewUser)) { return }

    try {
        if (!(Get-LocalUser -Name $NewUser -ErrorAction SilentlyContinue)) {
            $NewPass = Read-Host -AsSecureString "Enter Password for $NewUser"
            New-LocalUser -Name $NewUser -Password $NewPass -Description "Team Blue Admin" -PasswordNeverExpires $true
            Add-LocalGroupMember -Group "Administrators" -Member $NewUser
            $script:NewAdminName = $NewUser
            Update-Log "User" "Created Team Admin: $NewUser"
        }
    } catch { Update-Log "User" "ERROR: $($_.Exception.Message)" }
}

function Set-AdministratorAccount {
    Write-Host "`n--- Step 3: Secure Built-in Local Admin (SID -500) ---" -ForegroundColor Yellow
    try {
        # Target by SID in case the account was renamed by Red Team
        $AdminAccount = Get-LocalUser | Where-Object { $_.SID -like "S-1-5-21-*-500" }
        $AdminName = $AdminAccount.Name
        
        $Pass = Read-Host -AsSecureString "Set NEW Password for Built-in Admin ($AdminName)"
        Set-LocalUser -Name $AdminName -Password $Pass
        Disable-LocalUser -Name $AdminName
        
        Update-Log "Admin" "Built-in Admin ($AdminName) password rotated and account disabled."
    } catch { Update-Log "Admin" "ERROR: $($_.Exception.Message)" }
}

function Disable-NonEssentialUsers {
    Write-Host "`n--- Step 4: Disable Non-Essential Users ---" -ForegroundColor Yellow
    $Criticals = @("Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount", $script:NewAdminName) 
    $Users = Get-LocalUser | Where-Object { $_.Enabled -eq $true -and $_.Name -notin $Criticals }
    
    foreach ($u in $Users) {
        Disable-LocalUser -Name $u.Name
        Update-Log "User-Audit" "Disabled local user $($u.Name)"
    }
}

# --- Harden OS  ---
function Harden-OS {
    Write-Host "`n--- Step 5: Protocol & Anti-Backdoor Hardening ---" -ForegroundColor Yellow

    # Disable LLMNR (Prevents Responder attacks)
    $DNSPath = "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient"
    if (!(Test-Path $DNSPath)) { New-Item -Path $DNSPath -Force }
    Set-ItemProperty -Path $DNSPath -Name "EnableMulticast" -Value 0 -Type DWord

    # Sticky Keys Backdoor Prevention (Sets flags to disable shortcut)
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "506"

    # LSASS Protection & SMB Hardening
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -Type DWord -Force
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
    
    # PrintNightmare Fix
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Set-Service Spooler -StartupType Disabled

    Update-Log "OS-Hardening" "LLMNR disabled, StickyKeys hardened, LSASS protected, Spooler killed."
}

# --- Firewall ---
function Configure-Firewall {
    Write-Host "`n--- Step 6: MWCCDC Firewall Policy ---" -ForegroundColor Yellow
    
    netsh advfirewall reset
    # We allow outbound by default so we don't break DNS/Scoring dependencies
    netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound
    
    # Rule 14: MANDATORY ICMP INBOUND
    netsh advfirewall firewall add rule name="MWCCDC-ICMP-In" protocol=icmpv4 dir=in action=allow
    
    # Logging Outbound for Splunk (System 3)
    netsh advfirewall firewall add rule name="MWCCDC-Splunk-Out" dir=out action=allow protocol=TCP remoteport=8000,9997

    Update-Log "Firewall" "Rule 14 ICMP Inbound Allowed. Inbound Blocked. Outbound Allowed."
}

# --- Disable NetBIOS ---
function Disable-NetBIOS {
    Write-Host "`n--- Step 7: Disabling NetBIOS ---" -ForegroundColor Yellow
    $adapters = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    foreach ($adapter in $adapters) { 
        Invoke-CimMethod -InputObject $adapter -MethodName SetTcpipNetbios -Arguments @{TcpipNetbiosOptions = 2} | Out-Null 
    }
    Update-Log "Network" "NetBIOS Disabled."
}

# --- EXECUTION FLOW ---
Emergency-Backup          # Backup
CreateAdmin               # Team Admin
Set-AdministratorAccount   # Secure Built-in Admin
Disable-NonEssentialUsers # Audit Users
Harden-OS                 # Protocols & Registry
Configure-Firewall        # Firewall (Rule 14)
Disable-NetBIOS           # NetBIOS

Write-Host "`n--- STANDALONE HARDENING COMPLETE ---" -ForegroundColor Cyan
Write-Host "Proceed with service-specific scripts (HTTP/FTP)." -ForegroundColor Gray