function Harden-Banners {
    Write-Host "`n--- Step 12: Advanced Anti-Reconnaissance (Standalone Server Focus) ---" -ForegroundColor Yellow

    # 1. TCP/IP STACK (OS Fingerprint Deception)
    try {
        $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        # Set TTL to 64 (Typical of Linux) to confuse OS scanners like Nmap
        Set-ItemProperty -Path $TcpPath -Name "DefaultTTL" -Value 64 -Type DWord -Force
        # Disable TCP Window Scaling timestamps to reduce uptime leakage
        Set-ItemProperty -Path $TcpPath -Name "Tcp1323Opts" -Value 0 -Type DWord -Force
        Write-Host "[+] TCP Stack Spoofed (TTL=64)." -ForegroundColor Green
    } catch { Write-Warning "TCP stack modification failed." }

    # 2. LOCAL ACCOUNT RECON PROTECTION (Non-AD Replacement for LDAP Hardening)
    try {
        $LsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        # Restrict anonymous SID lookups and account enumeration
        Set-ItemProperty -Path $LsaPath -Name "RestrictAnonymous" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $LsaPath -Name "RestrictAnonymousSAM" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $LsaPath -Name "EveryoneIncludesAnonymous" -Value 0 -Type DWord -Force
        Write-Host "[+] Local Account Enumeration Restricted (Anonymous Recon blocked)." -ForegroundColor Green
    } catch { Write-Warning "Local security policy hardening failed." }

    # 3. SMB HARDENING (Null Session & Banner Protection)
    try {
        $LanManPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
        # SMB Server Name Hardening (prevents spoofing)
        Set-ItemProperty -Path $LanManPath -Name "SMBServerNameHardeningLevel" -Value 1 -Type DWord -Force
        # Ensure SMB1 is explicitly killed at the registry level
        Set-ItemProperty -Path $LanManPath -Name "SMB1" -Value 0 -Type DWord -Force
        # Restrict Null Session Access (prevent unauthenticated pipe access)
        Set-ItemProperty -Path $LanManPath -Name "RestrictNullSessAccess" -Value 1 -Type DWord -Force
        Write-Host "[+] SMB Null Sessions & SMBv1 Disabled." -ForegroundColor Green
    } catch { Write-Warning "SMB Hardening failed." }

    # 4. RDP & IIS BANNER SCRUBBING
    try {
        # Disable RDP if not explicitly needed (Recommended for high security)
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 1 -Force
        
        # IIS/HTTP Header Scrubbing (Prevents "Server: Microsoft-IIS/10.0" leakage)
        $HttpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters"
        if (-not (Test-Path $HttpPath)) { New-Item $HttpPath -Force | Out-Null }
        Set-ItemProperty -Path $HttpPath -Name "DisableServerHeader" -Value 1 -Type DWord -Force
        Write-Host "[+] RDP Disabled & HTTP Server Headers Scrubbed." -ForegroundColor Green
    } catch { Write-Warning "RDP/IIS scrubbing failed." }

    # 5. LEGACY/LEAKY SERVICES
    # Removed AD-specific services; focused on general leaky protocols
    $Leaky = @("TlntSvr", "msftpsvc", "SimpTcp", "RemoteRegistry", "W3SVC") 
    foreach ($s in $Leaky) {
        if (Get-Service $s -ErrorAction SilentlyContinue) {
            Stop-Service $s -Force -Confirm:$false -ErrorAction SilentlyContinue
            Set-Service $s -StartupType Disabled
            Write-Host "[!] Killed Leaky Service: $s" -ForegroundColor Red
        }
    }

    # Logging
    if (Get-Command Update-Log -ErrorAction SilentlyContinue) {
        Update-Log "Anti-Recon" "Banner and Stack hardening complete for standalone server."
    } else {
        Write-Host "Anti-Recon: Complete." -ForegroundColor Cyan
    }
}