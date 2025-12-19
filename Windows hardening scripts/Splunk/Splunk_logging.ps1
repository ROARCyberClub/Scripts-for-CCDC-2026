#Requires -RunAsAdministrator

# --- CONFIGURATION ---
$SplunkIndexer = "ip_address"
$IndexerPort   = "9997"
$SplunkPath    = "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe"
$DownloadUrl   = "Splunk_Url"
$MsiPath       = "$env:TEMP\splunk_uf.msi"

Write-Host "--- MWCCDC Splunk Setup ---" -ForegroundColor Cyan

# 1. OPEN FIREWALL (Do this first so the installer can phone home)
Write-Host "[!] Opening Firewall Port TCP 9997..." -ForegroundColor Yellow
netsh advfirewall firewall add rule name="CCDC-Splunk-Out" dir=out action=allow protocol=TCP remoteport=$IndexerPort remoteip=$SplunkIndexer

# 2. CHECK IF INSTALLED
if (Test-Path $SplunkPath) {
    Write-Host "[+] Splunk is already installed. Skipping installation." -ForegroundColor Green
} else {
    Write-Host "[-] Splunk NOT found. Downloading from internet..." -ForegroundColor Yellow
    try {
        # Download the MSI
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $MsiPath -ErrorAction Stop
        
        Write-Host "[!] Installing Splunk silently..." -ForegroundColor Yellow
        # Silent Install: Agrees to license, sets the indexer, and starts the service
        $InstallArgs = "/i `"$MsiPath`" AGREETOLICENSE=Yes RECEIVING_INDEXER=`"$($SplunkIndexer):$($IndexerPort)`" LAUNCHSPLUNK=1 /quiet"
        Start-Process msiexec.exe -ArgumentList $InstallArgs -Wait
        
        Write-Host "[+] Installation complete." -ForegroundColor Green
    } catch {
        Write-Error "Failed to download or install Splunk. Check internet connectivity."
        return
    }
}

# 3. CONFIGURE LOG SOURCES
if (Test-Path $SplunkPath) {
    Write-Host "[!] Configuring Log Sources..." -ForegroundColor Yellow
    
    # Point to indexer (in case it wasn't set during install)
    & $SplunkPath add forward-server "$($SplunkIndexer):$($IndexerPort)" -auth admin:changeme
    
    # Monitor standard Windows logs
    & $SplunkPath add eventlog Security -sourcetype WinEventLog:Security
    & $SplunkPath add eventlog System -sourcetype WinEventLog:System
    & $SplunkPath add eventlog Application -sourcetype WinEventLog:Application
    
    # Monitor Web Logs if this is the Docker/Web server
    if (Test-Path "C:\inetpub\logs\LogFiles") {
        & $SplunkPath add monitor "C:\inetpub\logs\LogFiles\*" -sourcetype iis
    }

    # Restart to ensure everything is running
    Restart-Service SplunkForwarder -ErrorAction SilentlyContinue
    Write-Host "[SUCCESS] Logs are now being sent to $SplunkIndexer" -ForegroundColor Green
}

# 4. CLEANUP
if (Test-Path $MsiPath) { Remove-Item $MsiPath }