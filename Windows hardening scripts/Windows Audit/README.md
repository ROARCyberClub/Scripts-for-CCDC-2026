# Get-DomainPrivilegeReport.ps1

Targeted Audit: Automatically scans for members of the most sensitive security groups:
Domain Admins
Enterprise Admins
Built-in Administrators
Remote Desktop Users
Status Detection: Reports whether privileged accounts are Enabled or Disabled.
Deep Group Analysis: Extracts and lists every group a privileged user belongs to (delimited by semicolons) for easy cross-referencing.
Performance Optimized: Uses fast string parsing for Distinguished Names to handle larger user bases efficiently.
CSV Export: Generates a professional DomainPrivilegeReport.csv for documentation or Incident Response (IR) reports.
