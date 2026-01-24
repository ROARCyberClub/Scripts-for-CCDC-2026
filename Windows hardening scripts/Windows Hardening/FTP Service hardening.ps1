
# --- Variables ---
$FtpSiteName = "Default FTP Site" # Standard IIS name
$FtpRoot = "C:\inetpub\ftproot"
$RequireSSL = $true  # SET TO $false IF SCORING ENGINE BREAKS

Import-Module WebAdministration

Write-Host "--- Starting FTP Hardening for VM #7 ---" -ForegroundColor Cyan

# Disable Anonymous Authentication (Critical)
Write-Host "Disabling Anonymous Auth and Enabling Basic Auth..."
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $false
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/authentication/basicAuthentication" -Name "enabled" -Value $true

# Add Authorization Rule (Without this, Basic Auth still returns 'Access Denied')
Write-Host "Adding FTP Authorization Rules for All Users..."
if (!(Get-WebConfiguration -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/authorization/add[@users='*']")) {
    Add-WebConfigurationRule -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/authorization" -Value @{accessType="Allow"; users="Score Users"; permissions="Read, Write"}
}

# Configure FTP Brute Force Protection
Write-Host "[+] Configuring FTP Logon Attempt Restrictions..."
Set-WebConfigurationProperty -Filter "/system.ftpServer/security/unlimitedLogonAttempt" -Name "enabled" -Value $false
Set-WebConfigurationProperty -Filter "/system.ftpServer/security/unlimitedLogonAttempt" -Name "maxLogonAttempts" -Value 5
Set-WebConfigurationProperty -Filter "/system.ftpServer/security/unlimitedLogonAttempt" -Name "lockoutWindow" -Value 15

# Configure SSL (FTPS)
if ($RequireSSL) {
    Write-Host "Generating Self-Signed Certificate and Enforcing SSL..."
    $cert = New-SelfSignedCertificate -DnsName "ftp.ccdc.local" -CertStoreLocation "cert:\LocalMachine\My"
    $thumb = $cert.Thumbprint

    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/ssl" -Name "serverCertHash" -Value $thumb
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/ssl" -Name "controlChannelPolicy" -Value "SslRequire"
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/ssl" -Name "dataChannelPolicy" -Value "SslRequire"
} else {
    Write-Host "Skipping SSL enforcement (Plaintext Mode)..." -ForegroundColor Yellow
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/ssl" -Name "controlChannelPolicy" -Value "SslAllow"
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/security/ssl" -Name "dataChannelPolicy" -Value "SslAllow"
}

# Configure Passive Port Range (Crucial for Firewall/SSL Compatibility)
Write-Host "Configuring Passive Port Range (5000-5100)..."
Set-WebConfigurationProperty -Filter "/system.ftpServer/firewallSupport" -Name "lowDataChannelPort" -Value 5000
Set-WebConfigurationProperty -Filter "/system.ftpServer/firewallSupport" -Name "highDataChannelPort" -Value 5100


# Enable Enhanced Logging
Write-Host "Enhancing FTP Logging..."
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/logFile" -Name "directory" -Value "C:\inetpub\logs\LogFiles"
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/logFile" -Name "logExtFileFlags" -Value "Date,Time,ClientIP,UserName,SiteName,ComputerName,ServerIP,Method,UriStem,HttpStatus,Win32Status,BytesSent,BytesRecv,TimeTaken,ServerPort,UserAgent,Cookie,Referer,ProtocolVersion,Host,HttpSubStatus"

# User Isolation 
# WARNING: If NISE scoring fails, disable isolation. Scoring engines often expect files in the literal root.
Write-Host "Enabling User Isolation..."
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$FtpSiteName']/ftpServer/userIsolation" -Name "mode" -Value "IsolateAllDirectoriesWithUserSpecificPhysicalDirectory"

if (!(Test-Path "$FtpRoot\LocalUser")) {
    New-Item -ItemType Directory -Path "$FtpRoot\LocalUser" | Out-Null
}

# NTFS Permissions Hardening
Write-Host "Hardening NTFS Permissions on FTP Root..."
icacls $FtpRoot /inheritance:d | Out-Null
icacls $FtpRoot /remove "Everyone" | Out-Null
icacls $FtpRoot /remove "Users" | Out-Null
icacls $FtpRoot /grant "Administrators:(OI)(CI)F" | Out-Null
icacls $FtpRoot /grant "SYSTEM:(OI)(CI)F" | Out-Null

# Restart the FTP Service
Write-Host "Restarting Microsoft FTP Service..." -ForegroundColor Cyan
Restart-Service ftpsvc

Write-Host "--- Hardening Complete. Check NISE for 'Green' status! ---" -ForegroundColor Green