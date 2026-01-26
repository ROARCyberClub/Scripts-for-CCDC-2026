$WebRoot = "C:\inetpub\wwwroot"
$Backup  = "C:\opt\web_backup"
$LogFile = "C:\Windows\System32\LogFiles\Defacement.log"

# Create Backup if it doesn't exist
if (-not (Test-Path -Path $Backup)) {
    Write-Host "Creating Backup..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $Backup -Force
    Copy-Item -Path "$WebRoot\*" -Destination $Backup -Recurse -Force
}

Write-Host "Monitoring web files for defacement... (Press Ctrl+C to stop)" -ForegroundColor Yellow

# Monitoring Loop
while ($true) {
    # Compare the two directories
    $diff = Compare-Object -ReferenceObject (Get-ChildItem -Path $Backup -Recurse) `
                           -DifferenceObject (Get-ChildItem -Path $WebRoot -Recurse)

    if ($null -ne $diff) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $msg = "Defacement detected at $timestamp"
        
        # Log and display
        Write-Host $msg -ForegroundColor Red
        $msg | Out-File -FilePath $LogFile -Append

        # Restore (using Robocopy for speed and efficiency)
        robocopy $Backup $WebRoot /MIR /V /NP /R:3 /W:5 | Out-Null
        
        Write-Host "[+] Website restored." -ForegroundColor Green
    }

    Start-Sleep -Seconds 10
}