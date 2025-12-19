#Requires -RunAsAdministrator

Write-Host "--- Simple Windows Update (No Auto-Reboot) ---" -ForegroundColor Cyan

# 1. Open Firewall for Windows Update
Write-Host "[!] Opening Firewall for 80,443..." -ForegroundColor Yellow
netsh advfirewall firewall add rule name="Allow-WinUpdate-Out" dir=out action=allow protocol=TCP remoteport=80,443

# 2. Search for missing Security and Critical updates
Write-Host "[!] Searching for updates (this may take a minute)..." -ForegroundColor Yellow
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")

$UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

foreach ($Update in $SearchResult.Updates) {
    # Only grab Security or Critical updates to save time
    if ($Update.Categories | Where-Object { $_.Name -eq "Security Updates" -or $_.Name -eq "Critical Updates" }) {
        $UpdatesToInstall.Add($Update) | Out-Null
    }
}

if ($UpdatesToInstall.Count -eq 0) {
    Write-Host "[+] No critical security updates found." -ForegroundColor Green
    exit
}

Write-Host "[+] Found $($UpdatesToInstall.Count) updates. Downloading..." -ForegroundColor Cyan

# 3. Download Updates
$Downloader = $UpdateSession.CreateUpdateDownloader()
$Downloader.Updates = $UpdatesToInstall
$Downloader.Download()

# 4. Install Updates
Write-Host "[!] Installing updates... DO NOT CLOSE..." -ForegroundColor Yellow
$Installer = $UpdateSession.CreateUpdateInstaller()
$Installer.Updates = $UpdatesToInstall
$InstallationResult = $Installer.Install()

# 5. Final Status
Write-Host "--- Patching Complete ---" -ForegroundColor Cyan
if ($InstallationResult.RebootRequired) {
    Write-Host "[WARNING] A reboot is REQUIRED to finish patching, but I will not do it automatically." -ForegroundColor Red
} else {
    Write-Host "[+] Updates installed. No reboot required at this time." -ForegroundColor Green
}