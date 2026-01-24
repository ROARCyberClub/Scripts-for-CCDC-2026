# Banner Grabbing countermeasures.ps1
Run As Administrator. Run on AD/DNS machine
TCP/IP Stack Spoofing: Changes the Default TTL to 64 (mimicking a different OS) and modifies TCP options to frustrate OS fingerprinting tools like Nmap.
LDAP Hardening (AD/DNS):
Enforces LDAP Server Integrity and Channel Binding.
Denies Unauthenticated (Anonymous) Binds, preventing the Red Team from dumping user lists or AD structure without credentials.
SMB Lockdown:
Restricts Null Session access (prevents net view or anonymous enumeration).
Enforces SMB Name Hardening and ensures SMBv1 is disabled.
IIS Banner Scrubbing: Disables the Server header in HTTP responses (Server 2019+), preventing the Red Team from seeing the exact IIS/Windows version via web requests.
RDP Lockdown: Disables Remote Desktop connections by default to prevent lateral movement.
Leaky Service Cleanup: Identifies and kills high-risk legacy services including Telnet, FTP (Simple), and Remote Registry.


# local_windows_server_banner-grabbing_measures.ps1

Run as Administrator. Run on Non-AD machines.

OS Fingerprint Deception:
Changes the Default TTL to 64 (making the Windows server appear like a Linux/Unix system to scanners like nmap).
Disables TCP Window Scaling timestamps to prevent uptime leakage and clock-skew fingerprinting.
Anonymous Recon Block:
Restricts anonymous SID lookups and SAM account enumeration.
Prevents the Red Team from listing local usernames or groups without a valid login.
SMB Lockdown:
Explicitly kills SMBv1 and restricts Null Sessions.
Enforces SMB Server Name Hardening to prevent spoofing/relay attacks.
Banner Scrubbing:
Disables the HTTP Server Header (effectively hiding the Microsoft-IIS/10.0 version string from web scanners).
Disables Remote Registry to prevent remote configuration scanning.
Service Minimization: Identifies and disables "leaky" legacy protocols including Telnet, Simple TCP, and unencrypted FTP.
