# Splunk_logging.ps
Run as Administrator

Silent Automated Install: Downloads and installs the Splunk UF (v10.0.2) in the background without requiring user interaction.

Dynamic Service Detection: The script "identifies" the server role upon execution and configures logging accordingly:

All Systems: Collects Windows Event Logs (Security, System, and Application).

VM #5 (AD/DNS): Automatically detects the DNS service and adds monitors for DNS Server logs.

VM #6 & #7 (Web/FTP): Detects IIS directories and adds monitors for W3C/Web/FTP logs.

Sysmon Integration: If you have Sysmon installed, the script automatically detects it and begins shipping operational logs.

Pre-Configured Outputs: Automatically points all traffic to the competition indexer at 172.20.242.20:9997 (VM #3).

Clean Deployment: Handles its own directory creation and cleans up the .msi installer after completion to save disk space.
