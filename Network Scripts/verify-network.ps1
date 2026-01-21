Write-Host ""
Write-Host "-=-=- Network Information -=-=-"
Write-Host ""

$gateway = Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1
$interface = Get-NetAdapter -InterfaceIndex $gateway.InterfaceIndex


Write-Host "-Network Interface-"
Write-Host "$($interface.InterfaceAlias) [$($interface.InterfaceDescription)]"
Write-Host "ID: $($interface.InterfaceGuid)"
Write-Host ""
Write-Host ""

Write-Host "-Local IP-"
$ipInfo = Get-NetIPAddress -InterfaceIndex $gateway.InterfaceIndex -AddressFamily IPv4
Write-Host "$($ipInfo.IPAddress)/$($ipInfo.PrefixLength)"
Write-Host ""
Write-Host ""

Write-Host "-Default Gateway-"
Write-Host $gateway.NextHop
Write-Host ""
Write-Host ""

Write-Host "-Pinging Gateway-"
Test-Connection -ComputerName $gateway.NextHop -Count 3 | Select-Object `
    Address, 
    @{Name="Status"; Expression={if($_.StatusCode -eq 0){"Success"}else{"Error: "+$_.StatusCode}}},
    @{Name="Latency(ms)"; Expression={$_.ResponseTime}} | Format-Table -AutoSize
Write-Host ""
Write-Host ""

Write-Host "-DNS Resolution Test (google.com)-"
Resolve-DnsName -Name google.com | Select-Object Name, IPAddress | Format-Table
Write-Host ""
Write-Host ""

Write-Host "-Ports and Services-"
Write-Host " - TCP"
Get-NetTCPConnection -State Listen | Select-Object @{Name="Protocol";Expression={"TCP"}}, LocalPort, @{Name="Process";Expression={(Get-Process -Id $_.OwningProcess).ProcessName}} | Select-Object -First 10 | Format-Table -AutoSize
Write-Host " - UDP"
Get-NetUDPEndpoint | Select-Object @{Name="Protocol";Expression={"UDP"}}, LocalPort, @{Name="Process";Expression={try{(Get-Process -Id $_.OwningProcess).ProcessName}catch{"Unknown"}}} | Select-Object -First 10 | Format-Table -AutoSize