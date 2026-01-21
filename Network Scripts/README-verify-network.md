# Scripts-for-CCDC-2026
-=-=- Network Verification Script -=-=-
A lightweight, multi-platform network diagnostic tool to quickly audit network interfaces, connectivity, and open ports.

-Features-
 - Interface Detection: Identifies the active network adapter and gateway.
 - IP Auditing: Displays local IPv4 addresses with CIDR prefix notation.
 - Connectivity Tests: Performs gateway pings and DNS resolution checks.
 - Port & Service Audit: Lists all active TCP/UDP listening ports and the specific processes using them.

Linux Version (verify-network.sh)
Prerequisites
The script uses lsof for port detection because it provides a more stable output for UDP than ss or netstat.

Windows Version (verify-network.ps1)
Prerequisites
You must allow script execution on your machine for PowerShell scripts to run. {PowerShell}->[Set-ExecutionPolicy RemoteSigned -Scope CurrentUser]

-=- Technical Details -=-
Port Detection Logic
The Linux version uses the following pipeline to ensure accurate results even with IPv6 and connectionless UDP: sudo lsof -i -P -n | grep -E 'LISTEN|UDP' | awk ...

-i: Filters for internet-based connections.
-P: Forces port numbers instead of service names for easier reading.
-n: Skips DNS reverse lookups to speed up execution.

Network Mapping
The script dynamically pulls the interface name by inspecting the default routing table rather than using hardcoded values.

Troubleshooting
Empty Process Names: If the "Services" column is empty, ensure you are running the script with sudo or as an Administrator.

DNS Failures: If the DNS test fails but the Gateway ping succeeds, check your /etc/resolv.conf (Linux) or your adapter's DNS settings (Windows).
