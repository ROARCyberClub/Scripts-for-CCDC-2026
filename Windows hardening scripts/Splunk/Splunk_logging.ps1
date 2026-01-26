# ==============================================================================
# 2026 MWCCDC - UNIVERSAL Windows Splunk UF Deployment
# Targets: VM #5, #6, #7, and #8
# ==============================================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------------------------
# 1. COMPETITION VARIABLES
# ------------------------------------------------------------------------------
$INDEXER_IP   = "172.20.242.20"  # VM #3 (Splunk Server)
$INDEXER_PORT = "9997"

$UF_ADMIN_USER = "admin"
$UF_ADMIN_PASS = "Changeme123!" # Change me

$SPLUNK_HOME   = "C:\Program Files\SplunkUniversalForwarder"
$DOWNLOAD_DIR  = "$env:TEMP\splunk_uf"
$MSI_URL       = "https://download.splunk.com/products/universalforwarder/releases/10.0.2/windows/splunkforwarder-10.0.2-e2d18b4767e9-windows-x64.msi"
$MSI_PATH      = "$DOWNLOAD_DIR\splunk_uf.msi"

# Identify the machine for Splunk 
$HOSTNAME = $env:COMPUTERNAME 

# ------------------------------------------------------------------------------
# 2. HELPER FUNCTIONS
# ------------------------------------------------------------------------------
function Log($msg)  { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [+] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [!] $msg" -ForegroundColor Yellow }

# ------------------------------------------------------------------------------
# 3. INSTALLATION LOGIC
# ------------------------------------------------------------------------------
if (-not (Test-Path "$SPLUNK_HOME\bin\splunk.exe")) {
    if (!(Test-Path $DOWNLOAD_DIR)) { New-Item -ItemType Directory -Path $DOWNLOAD_DIR | Out-Null }
    
    Log "Downloading Splunk UF for $HOSTNAME..."
    Invoke-WebRequest -Uri $MSI_URL -OutFile $MSI_PATH -UserAgent "PowerShell"

    Log "Installing Silently..."
    $installArgs = @(
        "/i", "`"$MSI_PATH`"",
        "AGREETOLICENSE=Yes",
        "INSTALLDIR=`"$SPLUNK_HOME`"",
        "SPLUNKUSERNAME=$UF_ADMIN_USER",
        "SPLUNKPASSWORD=$UF_ADMIN_PASS",
        "SERVICESTARTTYPE=auto",
        "/qn"
    )
    Start-Process msiexec.exe -ArgumentList $installArgs -Wait
} else {
    Warn "Splunk UF already installed on $HOSTNAME."
}

# ------------------------------------------------------------------------------
# 4. DYNAMIC LOG DISCOVERY (The "Universal" Part)
# ------------------------------------------------------------------------------
$LOCAL_CONF = "$SPLUNK_HOME\etc\system\local"

# Base configuration for EVERY Windows machine
$inputsContent = @"
[default]
host = $HOSTNAME

[WinEventLog://Security]
index = main
disabled = false

[WinEventLog://System]
index = main
disabled = false

[WinEventLog://Application]
index = main
disabled = false
"@

# --- AUTO-DETECTION LOGIC ---

# 1. Detect IIS/Web/FTP (VM #6, VM #7)
if (Test-Path "C:\inetpub\logs\LogFiles") {
    Log "Detected IIS/FTP - Adding Web Log Monitors..."
    $inputsContent += @"

[monitor://C:\inetpub\logs\LogFiles\*]
index = main
sourcetype = ms:iis:auto
disabled = false
"@
}

# 2. Detect DNS Server (VM #5)
if (Get-Service "DNS" -ErrorAction SilentlyContinue) {
    Log "Detected DNS Server - Adding DNS Log Monitors..."
    $inputsContent += @"

[WinEventLog://DNS Server]
index = main
disabled = false

[monitor://C:\Windows\System32\dns\dns.log]
index = main
sourcetype = dns
disabled = false
"@
}

# 3. Detect DHCP Server
if (Get-Service "DHCPServer" -ErrorAction SilentlyContinue) {
    Log "Detected DHCP Server - Adding DHCP Log Monitors..."
    $inputsContent += @"

[monitor://C:\Windows\System32\dhcp\DhcpSrvLog*]
index = main
sourcetype = dhcp
disabled = false
"@
}

# 4. Detect Sysmon (If you installed it)
if (Get-Service "Sysmon" -ErrorAction SilentlyContinue) {
    Log "Detected Sysmon - Adding Sysmon Monitor..."
    $inputsContent += @"

[WinEventLog://Microsoft-Windows-Sysmon/Operational]
index = main
disabled = false
"@
}

# ------------------------------------------------------------------------------
# 5. APPLY CONFIG & RESTART
# ------------------------------------------------------------------------------
Log "Applying Universal Config to $LOCAL_CONF..."

# Set Outputs
@"
[tcpout]
defaultGroup = primary_indexers

[tcpout:primary_indexers]
server = ${INDEXER_IP}:${INDEXER_PORT}
"@ | Set-Content "$LOCAL_CONF\outputs.conf" -Encoding ASCII

# Set Inputs
$inputsContent | Set-Content "$LOCAL_CONF\inputs.conf" -Encoding ASCII

Log "Restarting SplunkForwarder..."
Restart-Service SplunkForwarder -Force

# Cleanup
if (Test-Path $MSI_PATH) { Remove-Item $MSI_PATH -Force }

Log "DONE. $HOSTNAME is now shipping logs to VM #3."