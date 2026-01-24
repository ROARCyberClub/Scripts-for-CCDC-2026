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

It disables the Print Spooler service, NetBIOS, sand disables SMBv1.
