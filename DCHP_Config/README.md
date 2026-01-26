## DHCP Scripts

### windows
.\DHCP_Config.ps1
#### recovery
- cd C:\DHCP_Backup
- Import-DhcpServer -ComputerName $env:COMPUTERNAME -File "filename.xml" -Force
access denied?
- Set-ExecutionPolicy Unrestricted -Scope Process

### linux
chmod +x DHCP_Config.sh
sudo ./DHCP_Config.sh
#### recovery
cd /root/dhcp_backup
ls -l
cp dhcp.conf_backup_filename /etc/dhcp/dhcp.conf
- check dhcp.conf file location
service isc-dhcp-server restart
