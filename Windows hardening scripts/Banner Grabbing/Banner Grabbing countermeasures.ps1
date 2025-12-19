function Harden-Banners {
    Write-Host "Advanced Anti-Reconnaissance (AD/DNS/DHCP Focus) ---" -ForegroundColor Yellow

    # 1. TCP/IP STACK
    try {
        $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Set-ItemProperty -Path $TcpPath -Name "DefaultTTL" -Value 64 -Type DWord -Force
        Set-ItemProperty -Path $TcpPath -Name "Tcp1323Opts" -Value 0 -Type DWord -Force
        Write-Host "[+] TCP Stack Spoofed." -ForegroundColor Green
    } catch { Write-Warning "TCP stack modification failed." }

    # 2. LDAP HARDENING (With Module Check)
    if (Get-Module -ListAvailable ActiveDirectory) {
        try {
            $NtdsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters"
            Set-ItemProperty -Path $NtdsPath -Name "LdapServerIntegrity" -Value 2 -Type DWord -Force
            Set-ItemProperty -Path $NtdsPath -Name "LdapEnforceChannelBinding" -Value 2 -Type DWord -Force
            
            # Only attempt if it's a Domain Controller
            if ((Get-Service adws -ErrorAction SilentlyContinue) -and (Get-ADDomainController -ErrorAction SilentlyContinue)) {
                $DN = (Get-ADDomain).DistinguishedName
                $ConfigPath = "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$DN"
                Set-ADObject -Identity $ConfigPath -Replace @{"msDS-Other-Settings"="DenyUnauthenticatedBind=1"}
                Write-Host "[+] LDAP Anonymous Binds Disabled." -ForegroundColor Green
            }
        } catch { Write-Warning "LDAP Hardening failed (Check permissions/DC status)." }
    }

    # 3. SMB HARDENING
    try {
        $LanManPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
        Set-ItemProperty -Path $LanManPath -Name "SMBServerNameHardeningLevel" -Value 1 -Type DWord -Force
        # SMB1 is usually off in 2019/2022, but this ensures it for 2016
        Set-ItemProperty -Path $LanManPath -Name "SMB1" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $LanManPath -Name "RestrictNullSessAccess" -Value 1 -Type DWord -Force
        Write-Host "[+] SMB Hardened." -ForegroundColor Green
    } catch { Write-Warning "SMB Hardening failed." }

    # 4. RDP & IIS
    try {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 1 -Force
        
        # IIS Header Scrubbing (Effective on 2019/2022)
        $HttpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters"
        if (-not (Test-Path $HttpPath)) { New-Item $HttpPath -Force | Out-Null }
        Set-ItemProperty -Path $HttpPath -Name "DisableServerHeader" -Value 1 -Type DWord -Force
        Write-Host "[+] RDP Disabled & IIS Headers Scrubbed (2019+)." -ForegroundColor Green
    } catch { Write-Warning "RDP/IIS scrubbing failed." }

    # 5. SERVICES
    $Leaky = @("TlntSvr", "msftpsvc", "SimpTcp", "RemoteRegistry")
    foreach ($s in $Leaky) {
        if (Get-Service $s -ErrorAction SilentlyContinue) {
            Stop-Service $s -Force -Confirm:$false -ErrorAction SilentlyContinue
            Set-Service $s -StartupType Disabled
            Write-Host "[!] Killed Leaky Service: $s" -ForegroundColor Red
        }
    }

    # Fix: Ensure Update-Log exists or use Write-Host
    if (Get-Command Update-Log -ErrorAction SilentlyContinue) {
        Update-Log "Anti-Recon" "Hardening complete."
    } else {
        Write-Host "Anti-Recon: Full banner and stack hardening complete." -ForegroundColor Cyan
    }
}