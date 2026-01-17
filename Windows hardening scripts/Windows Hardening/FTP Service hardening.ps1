# ==============================================================================
# CCDC Windows Server 2022 FTP Hardening Script
# Target: VM #7 (Server 2022 FTP)
# ==============================================================================

# --- Variables ---
$FtpSiteName = "Default FTP Site" # Standard IIS name
$FtpRoot = "C:\inetpub\ftproot"
$RequireSSL = $true  # SET TO $false IF SCORING ENGINE BREAKS

Import-Module WebAdministration

Write-Host "--- Starting FTP Hardening for VM #7 ---" -ForegroundColor Cyan

# 1. Disable Anonymous Authentication (Critical)
Write-Host "[+] Disabling Anonymous Auth and Enabling Basic Auth..."
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $false
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/authentication/basicAuthentication" -Name "enabled" -Value $true

# 2. Configure FTP Brute Force Protection (Logon Attempt Restrictions)
# This prevents Red Team from hammering passwords.
Write-Host "[+] Configuring FTP Logon Attempt Restrictions (Brute Force Protection)..."
Set-WebConfigurationProperty -Filter "/system.ftpServer/security/unlimitedLogonAttempt" -Name "enabled" -Value $false
Set-WebConfigurationProperty -Filter "/system.ftpServer/security/unlimitedLogonAttempt" -Name "maxLogonAttempts" -Value 5
Set-WebConfigurationProperty -Filter "/system.ftpServer/security/unlimitedLogonAttempt" -Name "lockoutWindow" -Value 15

# 3. Configure SSL (FTPS)
if ($RequireSSL) {
    Write-Host "[+] Generating Self-Signed Certificate and Enforcing SSL..."
    
    # Create a self-signed cert for the FTP traffic
    $cert = New-SelfSignedCertificate -DnsName "ftp.ccdc.local" -CertStoreLocation "cert:\LocalMachine\My"
    $thumb = $cert.Thumbprint

    # Apply cert to the FTP Service
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/ssl" -Name "serverCertHash" -Value $thumb
    
    # Require SSL for both Control and Data channels
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/ssl" -Name "controlChannelPolicy" -Value "SslRequire"
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/ssl" -Name "dataChannelPolicy" -Value "SslRequire"
} else {
    Write-Host "[!] Skipping SSL enforcement (Plaintext Mode)..." -ForegroundColor Yellow
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/ssl" -Name "controlChannelPolicy" -Value "SslAllow"
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/ssl" -Name "dataChannelPolicy" -Value "SslAllow"
}

# 4. Enable Enhanced Logging (Crucial for Incident Reports)
Write-Host "[+] Enhancing FTP Logging..."
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/logFile" -Name "directory" -Value "C:\inetpub\logs\LogFiles"
# Log everything possible to help track Red Team
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/logFile" -Name "logExtFileFlags" -Value "Date,Time,ClientIP,UserName,SiteName,ComputerName,ServerIP,Method,UriStem,HttpStatus,Win32Status,BytesSent,BytesRecv,TimeTaken,ServerPort,UserAgent,Cookie,Referer,ProtocolVersion,Host,HttpSubStatus"

# 5. User Isolation (Prevent Directory Traversal)
Write-Host "[+] Enabling User Isolation..."
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/userIsolation" -Name "mode" -Value "IsolateAllDirectoriesWithUserSpecificPhysicalDirectory"

# Create the required directory structure for Isolation
if (!(Test-Path "$FtpRoot\LocalUser")) {
    New-Item -ItemType Directory -Path "$FtpRoot\LocalUser" | Out-Null
}

# 6. NTFS Permissions Hardening
Write-Host "[+] Hardening NTFS Permissions on FTP Root..."
# Disable inheritance and remove "Everyone" / "Users" access
icacls $FtpRoot /inheritance:d
icacls $FtpRoot /remove "Everyone"
icacls $FtpRoot /remove "Users"
icacls $FtpRoot /remove "Authenticated Users"
# Grant Administrators and SYSTEM full access
icacls $FtpRoot /grant "Administrators:(OI)(CI)F"
icacls $FtpRoot /grant "SYSTEM:(OI)(CI)F"

# 7. Restart the FTP Service to apply changes
Write-Host "[+] Restarting Microsoft FTP Service..." -ForegroundColor Cyan
Restart-Service ftpsvc

Write-Host "--- Hardening Complete. Check NISE for 'Green' status! ---" -ForegroundColor Green