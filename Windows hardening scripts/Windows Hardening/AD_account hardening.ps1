#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory

# --- Check Log ---
$LogPath = "C:\Temp\MWCCDC_Hardening.log"
if (!(Test-Path "C:\Temp")) { New-Item -ItemType Directory -Force -Path "C:\Temp" | Out-Null }

function Update-Log {
    param([string]$Action, [string]$Status)
    $Entry = "[$(Get-Date -Format 'HH:mm:ss')] - $Action - $Status"
    Add-Content -Path $LogPath -Value $Entry -Force
    Write-Host $Entry -ForegroundColor Cyan
}

# --- EMERGENCY BACKUP ---
function Emergency-Backup {
    Write-Host "`n[!] Creating Safety Backups..." -ForegroundColor Yellow
    $BackupPath = "C:\Backups_$(Get-Date -Format 'yyyyMMdd_HHmm')"
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    try {
        netsh advfirewall export "$BackupPath\FirewallConfig.wfw"
        Get-ADUser -Filter * -Properties * | Export-Csv "$BackupPath\Users.csv" -NoTypeInformation
        Update-Log "Backup" "Success: $BackupPath"
    } catch { Update-Log "Backup" "FAILED" }
}

# --- USER MANAGEMENT ---
function Manage-Users {
    Write-Host "`n--- User Management ---" -ForegroundColor Yellow
    
    # 2a. Create NEW Admin User
    $NewUser = Read-Host "Enter NEW Admin Username (e.g., BlueTeamAdmin)"
    if (!(Get-ADUser -Filter {SamAccountName -eq $NewUser})) {
        $NewPass = Read-Host -AsSecureString "Enter Password for $NewUser"
        New-ADUser -Name $NewUser -SamAccountName $NewUser -AccountPassword $NewPass -Enabled $true -PasswordNeverExpires $true
        Add-ADGroupMember -Identity "Domain Admins" -Members $NewUser
        Add-ADGroupMember -Identity "Administrators" -Members $NewUser
        Update-Log "User" "Created Custom Admin: $NewUser"
    }

    # Secure & Disable Built-in Admin 
    try {
        $AdminSid = (Get-ADUser -Filter "SID -like '*-500'").SID
        $RandPass = [Guid]::NewGuid().ToString() 
        Set-ADAccountPassword -Identity $AdminSid -NewPassword (ConvertTo-SecureString $RandPass -AsPlainText -Force)
        Disable-ADAccount -Identity $AdminSid
        Write-Host "SUCCESS: Built-in Administrator (SID-500) Disabled." -ForegroundColor Green
        Update-Log "User" "Disabled SID-500 Admin"
    } catch { Update-Log "User" "Error disabling SID-500" }

    # Whitelist Scored Users (Keeps them enabled for POP3/AD scoring)
    $Whitelist = @($NewUser, "Scored Users") 
    Write-Host "`nIdentify Scored users (Check the Packet/AD for POP3 accounts)." -ForegroundColor Cyan
    $InputUsers = Read-Host "Enter Scored usernames to whitelist (comma separated)"
    if ($InputUsers) { $Whitelist += $InputUsers.Split(',').Trim() }

    $AllUsers = Get-ADUser -Filter *
    foreach ($u in $AllUsers) {
        if ($u.SamAccountName -in $Whitelist) {
            # Ensure they are enabled 
            Set-ADUser -Identity $u -Enabled $true -ChangePasswordAtLogon $false
            Write-Host "Whitelisted & Enabled: $($u.SamAccountName)" -ForegroundColor Green
        } else {
            # Disable anyone not on the list (and not the already handled SID-500)
            if ($u.SID -notlike "*-500") {
                Disable-ADAccount -Identity $u
                Write-Host "Disabled Non-Essential: $($u.SamAccountName)" -ForegroundColor Red
            }
        }
    }
}

# --- 3. FIREWALL ---
function Configure-Firewall {
    Write-Host "`n--- Configuring Firewall (Inbound: Block | Outbound: Allow) ---" -ForegroundColor Yellow
    netsh advfirewall reset
    netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound

    # ICMP 
    netsh advfirewall firewall add rule name="MWCCDC-ICMP-In" protocol=icmpv4 dir=in action=allow

    # DNS 
    netsh advfirewall firewall add rule name="MWCCDC-DNS-In" dir=in action=allow protocol=UDP localport=53
    netsh advfirewall firewall add rule name="MWCCDC-DNS-TCP-In" dir=in action=allow protocol=TCP localport=53

    # AD/Authentication & RPC Dynamic
    $ADPorts = "88,135,389,445,464,636,3268,3269"
    netsh advfirewall firewall add rule name="MWCCDC-AD-In" dir=in action=allow protocol=TCP localport=$ADPorts
    netsh advfirewall firewall add rule name="MWCCDC-RPC-In" dir=in action=allow protocol=TCP localport=49152-65535

    # Corrected Splunk IP (Page 21)
    netsh advfirewall firewall add rule name="MWCCDC-Splunk-Out" dir=out action=allow protocol=TCP remoteaddress=172.20.242.20 remoteport=9997

    Update-Log "Firewall" "Rules Applied."
}

# --- OS HARDENING ---
function Harden-OS {
    Write-Host "`n--- Disabling Vulnerable Services ---" -ForegroundColor Yellow
    # PrintNightmare Fix
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Set-Service Spooler -StartupType Disabled
    
    # SMBv1 Disable
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
    
    Update-Log "OS-Hardening" "Spooler and SMBv1 disabled."
}

# --- EXECUTION ---
Emergency-Backup
Manage-Users
Harden-OS
Configure-Firewall

Write-Host "`n--- HARDENING COMPLETE ---" -ForegroundColor Green
Write-Host "Check your new Admin account before logging out!" -ForegroundColor Yellow
gpupdate /force