# Get-DomainPrivilegeReport.ps1

Targeted Audit: Automatically scans for members of the most sensitive security groups:
Domain Admins,
Enterprise Admins,
Built-in Administrators,
Remote Desktop Users

Status Detection: Reports whether privileged accounts are Enabled or Disabled.

Deep Group Analysis: Extracts and lists every group a privileged user belongs to (delimited by semicolons) for easy cross-referencing.

Performance Optimized: Uses fast string parsing for Distinguished Names to handle larger user bases efficiently.

CSV Export: Generates a professional DomainPrivilegeReport.csv for documentation or Incident Response (IR) reports.

# Get-LocalUserPrivilegeReport.ps1

Comprehensive Local Audit: Scans all local accounts (not just AD accounts) to identify memberships in high-privilege groups:
Administrators,
Remote Desktop Users,
Backup Operators,
Event Log Readers,
Power Users

Detailed Account Metadata: Captures the SID (Security Identifier) and Password Last Set date—critical for identifying if the Red Team has renamed an account or rotated a password.

Full Group Mapping: Lists every local group associated with every user, delimited by semicolons.

CSV Reporting: Generates a detailed LocalUserPrivilegeReport.csv for use in Incident Reports (IRs) or security baselining.

Clean Console Output: Provides a quick visual summary of enabled administrative accounts directly in the terminal.
