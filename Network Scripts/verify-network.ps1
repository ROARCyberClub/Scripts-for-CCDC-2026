Write-Host ""
Write-Host "-=-=- Network Information -=-=-"
Write-Host ""

$gateway = Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1
$interface = Get-NetAdapter -InterfaceIndex $gateway.InterfaceIndex


Write-Host "-Network Interface-"
Write-Host $interface.Name
Write-Host ""

Write-Host "-Local IP-"
$ipInfo = Get-NetIPAddress -InterfaceIndex $gateway.InterfaceIndex -AddressFamily IPv4
Write-Host $ipInfo.IPAddress
Write-Host ""

Write-Host "-Default Gateway-"
Write-Host $gateway.NextHop
Write-Host ""

Write-Host "-Ping Gateway-"
Test-Connection -ComputerName $gateway.NextHop -Count 3
Write-Host ""

Write-Host "-DNS Resolution Test (google.com)-"
Resolve-DnsName -Name google.com | Select-Object Name, IPAddress | Format-Table