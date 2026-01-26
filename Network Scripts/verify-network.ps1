Write-Host ""
Write-Host "-=-=- Network Information -=-=-"
Write-Host ""

# Attempt to find the IPv4 Default Route
$gateway = Get-NetRoute -DestinationPrefix 0.0.0.0/0 -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1

# If Gateway was found
if ($null -ne $gateway) {
    $interface = Get-NetAdapter -InterfaceIndex $gateway.InterfaceIndex

    Write-Host "-Network Interface-"
    Write-Host "$($interface.InterfaceAlias) [$($interface.InterfaceDescription)]"
    Write-Host "ID: $($interface.InterfaceGuid)"
    Write-Host ""

    Write-Host "-Local IP-"
    $ipInfo = Get-NetIPAddress -InterfaceIndex $gateway.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($ipInfo) {
        Write-Host "$($ipInfo.IPAddress)/$($ipInfo.PrefixLength)"
    }
    Write-Host ""

    Write-Host "-Default Gateway-"
    Write-Host $gateway.NextHop
    Write-Host ""

    Write-Host "-Pinging Gateway-"
    if ($null -ne $gateway.NextHop) {
        Test-Connection -ComputerName $gateway.NextHop -Count 3 -ErrorAction SilentlyContinue | Select-Object `
            Address, 
            @{Name="Status"; Expression={if($_.StatusCode -eq 0){"Success"}else{"Error: "+$_.StatusCode}}},
            @{Name="Latency(ms)"; Expression={$_.ResponseTime}} | Format-Table -AutoSize
    }
} else {
    Write-Host "[!] No IPv4 Default Route (0.0.0.0/0) found." -ForegroundColor Red
    Write-Host "Check your adapter settings or the VyOS router connection."
    Write-Host ""
}

# DNS Resolution Test
Write-Host ""
Write-Host "-DNS Resolution Test (google.com)-"
Resolve-DnsName -Name google.com -ErrorAction SilentlyContinue | Select-Object Name, IPAddress | Format-Table
Write-Host ""

# TCP Connections
Write-Host "-Ports and Services-"
Write-Host " - TCP"
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object @{Name="Protocol";Expression={"TCP"}}, LocalPort, @{Name="Process";Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} | Select-Object -First 10 | Format-Table -AutoSize
# UDP Connections

Write-Host " - UDP"
Get-NetUDPEndpoint -ErrorAction SilentlyContinue | Select-Object @{Name="Protocol";Expression={"UDP"}}, LocalPort, @{Name="Process";Expression={try{(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}catch{"Unknown"}}} | Select-Object -First 10 | Format-Table -AutoSize
