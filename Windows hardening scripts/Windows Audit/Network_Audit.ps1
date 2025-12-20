# Live_State_Audit.ps1
# Part 2: Collects Live State (Network, Ports, Processes, Services, AD)

# --- Helpers & Setup ---
$desktop = [Environment]::GetFolderPath('Desktop')
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$folderPath = "$env:USERPROFILE\Desktop\Audit_LiveState_$timestamp"
$logFile = Join-Path $folderPath "Audit_Log.txt"

# Create the directory
New-Item -ItemType Directory -Force -Path $folderPath | Out-Null

Write-Host "Saving LIVE STATE results to: $folderPath`n" -ForegroundColor Cyan

function Log {
    param([string]$msg)
    $time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$time] $msg"
    $line | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host $line
}

Log "Starting Live State & Network Audit."

# 1) Network interfaces and IPs
try {
    $out = Join-Path $folderPath "1_network_interfaces.txt"
    Log "Collecting network interfaces..."
    Get-WmiObject Win32_NetworkAdapterConfiguration |
      Where-Object { $_.IPEnabled -eq $true } |
      Select-Object Description, IPAddress, MACAddress |
      Format-Table -AutoSize | Out-String | Out-File -FilePath $out -Encoding UTF8
} catch { Log "ERROR collecting network interfaces: $_" }

# 2) Open ports and associated processes (Complex Logic)
try {
    $out = Join-Path $folderPath "2_open_ports_mapped.txt"
    Log "Mapping open ports to processes (this may take a moment)..."
    $results = New-Object System.Collections.Generic.List[string]
    netstat -ano | Select-String "LISTENING" | ForEach-Object {
        $line = $_.ToString().Trim()
        $parts = $line -split '\s+'
        if ($parts.Count -ge 5) {
            $localEndpoint = $parts[1]
            $port = ($localEndpoint -split ':')[-1]
            $processId = $parts[-1]
            $process = Get-WmiObject Win32_Process -Filter "ProcessId=$processId" -ErrorAction SilentlyContinue
            $procName = if ($process) { $process.Name } else { 'N/A' }
            $results.Add("Port: $port - PID: $processId - Process: $procName")
        }
    }
    if ($results.Count -eq 0) { $results.Add("No LISTENING lines found.") }
    $results | Out-File -FilePath $out -Encoding UTF8
} catch { Log "ERROR collecting open ports: $_" }

# 3) Running services
try {
    $out = Join-Path $folderPath "3_running-services.txt"
    Log "Collecting running services..."
    Get-WmiObject Win32_Service |
      Where-Object { $_.State -eq 'Running' } |
      Select-Object Name, DisplayName, StartMode, ProcessId |
      Format-Table -AutoSize | Out-String | Out-File -FilePath $out -Encoding UTF8
} catch { Log "ERROR collecting running services: $_" }

# 4) Running processes (Performance & Executables)
try {
    $outProc = Join-Path $folderPath "4_running-processes_stats.txt"
    $outExe  = Join-Path $folderPath "4_running-processes_paths.txt"
    
    Log "Collecting process statistics..."
    Get-Process | Sort-Object CPU -Descending | Select-Object Id, Name, CPU, StartTime |
      Format-Table -AutoSize | Out-String | Out-File -FilePath $outProc -Encoding UTF8

    Log "Collecting executable paths..."
    Get-Process | Where-Object { $_.Path -and $_.Path -like '*.exe' } |
      Select-Object Name, Path, Id | Format-Table -AutoSize | Out-String | Out-File -FilePath $outExe -Encoding UTF8
} catch { Log "ERROR collecting processes: $_" }

# 5) Raw Netstat (Backup)
try {
    $out = Join-Path $folderPath "5_netstat_raw.txt"
    Log "Collecting raw netstat dump..."
    netstat -ano | Out-File -FilePath $out -Encoding UTF8
} catch { Log "ERROR writing raw netstat: $_" }

# 6) Domain Users (Requires AD Module)
try {
    $out = Join-Path $folderPath "6_DomainUsers.txt"
    Log "Attempting to collect Active Directory Users..."
    if (Get-Module -ListAvailable -Name ActiveDirectory) {
        Get-ADUser -Filter * | Select-Object Name, DistinguishedName, SamAccountName, EmailAddress | Out-File -FilePath $out -Encoding UTF8
        Log "Domain Users collected."
    } else {
        Log "WARNING: ActiveDirectory module not found. Skipping Domain User dump."
    }
} catch { Log "ERROR collecting AD Users: $_" }

Log "Live State Audit Completed."