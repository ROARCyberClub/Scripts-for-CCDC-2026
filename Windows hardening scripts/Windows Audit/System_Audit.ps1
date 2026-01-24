# System_Config_Audit.ps1
# Part 1: Collects Static Configuration (System Info, Users, Firewall, Tasks)

# --- Helpers & Setup ---
$desktop = [Environment]::GetFolderPath('Desktop')
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$folderPath = "$env:USERPROFILE\Desktop\Audit_Config_$timestamp"
$logFile = Join-Path $folderPath "Audit_Log.txt"

# Create the directory
New-Item -ItemType Directory -Force -Path $folderPath | Out-Null

Write-Host "Saving CONFIGURATION results to: $folderPath`n" -ForegroundColor Cyan

function Log {
    param([string]$msg)
    $time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$time] $msg"
    $line | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host $line
}

Log "Starting System Configuration Audit."

# 1) System info
try {
    $out = Join-Path $folderPath "1_systeminfo.txt"
    Log "Collecting system information..."
    systeminfo | Out-String | Out-File -FilePath $out -Encoding UTF8
} catch { Log "ERROR collecting system info: $_" }

# 2) User and account information
try {
    $outUsers = Join-Path $folderPath "2_local_users.txt"
    $outGroups = Join-Path $folderPath "2_local_groups.txt"
    $outAccounts = Join-Path $folderPath "2_account_policies.txt"
    
    Log "Collecting local users, groups, and policies..."
    net user | Out-String | Out-File -FilePath $outUsers -Encoding UTF8
    net localgroup | Out-String | Out-File -FilePath $outGroups -Encoding UTF8
    net accounts | Out-String | Out-File -FilePath $outAccounts -Encoding UTF8
} catch { Log "ERROR collecting user/account info: $_" }

# 3) Scheduled tasks
try {
    $out = Join-Path $folderPath "3_scheduledtasks.txt"
    Log "Collecting scheduled tasks..."
    schtasks /query /fo LIST | Out-String | Out-File -FilePath $out -Encoding UTF8
} catch { Log "ERROR collecting scheduled tasks: $_" }

# 4) Firewall rules
try {
    $out = Join-Path $folderPath "4_firewall-rules.txt"
    Log "Collecting firewall rules..."
    netsh advfirewall firewall show rule name=all | Out-String | Out-File -FilePath $out -Encoding UTF8
} catch { Log "ERROR collecting firewall rules: $_" }

Log "Configuration Audit Completed."