# AD_account hardening.ps1

How the Script Works
The script is designed to be a hardening tool that secures the system while keeping your scored services (DNS, AD, and Mail Auth) active.

Backup: Before it changes anything, it creates a folder at C:\Backups. It exports a copy of your current firewall rules and a list of all current AD users. if something breaks, you have a reference to fix it manually.

New Admin: It prompts you to create a custom admin account. This ensures you have access using a username the Red Team doesn't know.

It changes the password of the built-in "Administrator" account and disables it. 
Whitelist Users: It asks you for the names of "Scored Users" (like the ones used for the POP3/Mail service). It keeps those users enabled so the scoring engine doesn't fail, but it disables every other "junk" or "guest" account it finds.

Network Lockdown:
It resets the Windows Firewall to a "Block Inbound / Allow Outbound" state.

It explicitly opens ICMP (to comply with Rule 14), DNS (Port 53), and Active Directory ports (88, 389, 445, etc.) so your services keep scoring.

It allows logs to flow out to the Splunk server at the specified IP Address.

It disables the Print Spooler service, NetBIOS, SMBv1, and other server services not required for competition.

# local_Windows_server_hardening.ps1

Run as Administrator 
User Rotation: Uses SIDs to identify and rotate the built-in Administrator password, even if renamed.
Team Admin: Prompts to create a new, clean Administrative account for your team.
Protocol Hardening: Disables legacy and vulnerable protocols:
LLMNR & NetBIOS: Prevents Responder/Spoofing attacks.
SMBv1: Mitigates legacy file-sharing vulnerabilities.
Print Spooler: Protects against PrintNightmare-style exploits.
Anti-Backdoor: Hardens Sticky Keys registry flags to prevent common RDP/Physical bypasses.
LSASS Protection: Enables `RunAsPPL` to prevent credential dumping tools like Mimikatz.

Rule 14 (ICMP): The firewall policy explicitly allows **Inbound ICMP**. This ensures the NISE scoring engine can reach your machine, preventing "Service Down" point losses.
Scoring Uptime: Sets a "Default Inbound Block" but allows all Outbound traffic to ensure DNS and external service checks remain functional.

# Password and Account Lockout.ps1

Sets Password and Account Lockout policies 

Password Length: Minimum 12 characters.
Password History: Remembers the last 24 passwords (prevents reuse).
Password Age: Maximum 42 days.
Lockout Threshold: 3 failed attempts (stops brute-force).
Lockout Duration: 10-minute lockout.
Lockout Window: 10-minute reset window.

# DNS_Hardening.ps1

Emergency Backup: Automatically exports all DNS zones to `C:\Backups\DNS` before making changes.
Zone Security: Disables unauthenticated Zone Transfers and enforces Secure Dynamic Updates.
DDoS Protection: Configures Response Rate Limiting (RRL) to 15 responses/sec to mitigate amplification attacks while maintaining scoring uptime.
Anti-Recon: Hides the DNS server version and disables version queries.
Poisoning Prevention: Enables DNS Cache Locking (100%) and increases Socket Pool entropy.
MITM Protection: Blocks WPAD and ISATAP global queries to prevent local spoofing.

# FTP Service hardening.ps1

Run as Administrator
Authentication Lockdown: Disables Anonymous access and enforces Basic Authentication.
Authorization Control: Automatically adds rules to allow the "Score Users" group to log in (essential for points).
Brute Force Protection: Restricts failed logons to 5 attempts within a 15-minute window.
FTPS Enforcement (SSL): Generates a self-signed certificate and enforces SSL for both Control and Data channels to prevent credential sniffing.
Passive Port Management: Configures a dedicated port range (5000-5100) for firewall compatibility.
User Isolation: Enforces directory isolation to prevent Red Team "directory traversal" across the server.
NTFS Hardening: Strips "Everyone" and "Users" permissions from the FTP root, granting access only to Administrators and SYSTEM.
Enhanced Logging: Enables high-detail logging to assist with Incident Reports (IRs).

