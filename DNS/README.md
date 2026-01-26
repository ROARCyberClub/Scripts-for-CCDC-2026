# DNS_Record_Update.ps1

The script automates the lifecycle of DNS "A" records by following this logic for every entry in your CSV:

Lookup: It searches for an existing record matching the RecordName and ZoneName.

Comparison:
Match: If the record exists and the IP is already correct, it skips the update to avoid unnecessary traffic.

Mismatch: If the record exists but has a different IP, it updates the record in place.

Creation: If the record cannot be found (triggering an error), the script catches that error and automatically creates a brand-new "A" record.

Logging: It provides real-time, color-coded feedback (Cyan for processing, Green for success, Yellow for new creations).

Usage: 

Prepare the Data: Create a file named dns_updates.csv in the same directory as the script. Use the following format for your data:

Open as Administrator: Right-click the PowerShell icon and select Run as Administrator (this is required to modify DNS records).

Set Execution Policy (Optional): If your system restricts scripts, run this command to allow the script to run in your current session.

Run the Script: Navigate to the folder containing your script and execute it.

# dns_updates.ps1

Script Functions

Automated DNS Management: Reads a CSV file to bulk create or update DNS "A" records.

Comprehensive Logging: Automatically generates a timestamped log file (.txt) to audit all actions, including successes, skips, and errors.

Idempotent (Smart) Updates: Checks the existing IP address and only performs an update if the new IP is different, preventing unnecessary changes.

Auto-Creation: If a record from the CSV does not exist on the DNS server, the script automatically creates it.

Robust Error Handling: Catches and logs errors on a per-record basis, allowing the script to continue processing the rest of the list even if one entry fails.

Real-time Feedback: Provides color-coded output directly in the console for immediate status updates (e.g., green for updates, yellow for creations).

Usage: 

Prepare the CSV: Create a file named dns_updates.csv in the same folder as the script. It must have the headers: RecordName, ZoneName, and NewIP.

Run as Administrator: Open a PowerShell session with elevated (Administrator) privileges.

Set Execution Policy (If Needed): If you receive an error about scripts being disabled, run the command: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process.

Execute the Script: Run the script from the PowerShell console by typing its name, for example: .\Update-DnsWithLogs.ps1.

Review the Output: Monitor the on-screen messages for live status and check the generated DNS_Update_Log_... .txt file for a complete audit trail.
