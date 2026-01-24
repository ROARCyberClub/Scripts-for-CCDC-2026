# Banner Grabbing countermeasures.ps1

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
