# --- Configuration ---
$CSVPath = ".\dns_updates.csv"
$LogFile = ".\DNS_Update_Log_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"

# Function to write to both console and log file
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $FullMessage = "[$Stamp] $Message"
    Write-Host $Message -ForegroundColor $Color
    $FullMessage | Out-File -FilePath $LogFile -Append
}

# Check if CSV exists
if (-not (Test-Path $CSVPath)) {
    Write-Log "Error: CSV file not found at $CSVPath" -Color Red
    exit
}

$DNSData = Import-Csv -Path $CSVPath
Write-Log "Starting DNS batch update process..." -Color Cyan

foreach ($Row in $DNSData) {
    $Name = $Row.RecordName
    $Zone = $Row.ZoneName
    $TargetIP = $Row.NewIP

    try {
        $Existing = Get-DnsServerResourceRecord -ZoneName $Zone -Name $Name -RRType "A" -ErrorAction SilentlyContinue

        if ($null -ne $Existing) {
            $CurrentIP = $Existing.RecordData.IPv4Address.IPAddressToString
            if ($CurrentIP -eq $TargetIP) {
                Write-Log "SKIP: $Name.$Zone already matches $TargetIP." -Color Gray
            } else {
                $NewRec = $Existing.Clone()
                $NewRec.RecordData.IPv4Address = $TargetIP
                Set-DnsServerResourceRecord -OldInputObject $Existing -NewInputObject $NewRec -ZoneName $Zone
                Write-Log "UPDATE: $Name.$Zone changed from $CurrentIP to $TargetIP." -Color Green
            }
        } else {
            Add-DnsServerResourceRecordA -Name $Name -ZoneName $Zone -IPv4Address $TargetIP
            Write-Log "CREATE: $Name.$Zone added with IP $TargetIP." -Color Yellow
        }
    } catch {
        Write-Log "ERROR: Failed to process $Name.$Zone. Details: $($_.Exception.Message)" -Color Red
    }
}

Write-Log "Process Complete. Log saved to $LogFile" -Color Cyan
