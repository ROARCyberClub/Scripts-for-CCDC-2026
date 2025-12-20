# Import the CSV data
$CSVPath = ".\dns_updates.csv"
$DNSData = Import-Csv -Path $CSVPath

foreach ($Row in $DNSData) {
    $Name = $Row.RecordName
    $Zone = $Row.ZoneName
    $TargetIP = $Row.NewIP

    Write-Host "--- Processing: $Name.$Zone ---" -ForegroundColor Cyan

    try {
        # Check for existing record
        $Existing = Get-DnsServerResourceRecord -ZoneName $Zone -Name $Name -RRType "A" -ErrorAction Stop

        if ($Existing.RecordData.IPv4Address.IPAddressToString -eq $TargetIP) {
            Write-Host "No change needed for $Name." -ForegroundColor Gray
        } else {
            # Update existing
            $NewRecord = $Existing.Clone()
            $NewRecord.RecordData.IPv4Address = $TargetIP
            Set-DnsServerResourceRecord -OldInputObject $Existing -NewInputObject $NewRecord -ZoneName $Zone
            Write-Host "Updated $Name to $TargetIP" -ForegroundColor Green
        }
    } catch {
        # If record doesn't exist, create it
        Write-Host "Record $Name not found. Creating new..." -ForegroundColor Yellow
        Add-DnsServerResourceRecordA -Name $Name -ZoneName $Zone -IPv4Address $TargetIP
        Write-Host "Created $Name -> $TargetIP" -ForegroundColor Green
    }
}
