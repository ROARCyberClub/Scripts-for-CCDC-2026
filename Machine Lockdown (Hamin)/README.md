# CCDC 2026 Machine Lockdown Scripts

**Automated Defense & Hardening Toolkit** for Linux servers in **CCDC (Collegiate Cyber Defense Competition) 2026**.
This project is intended to quickly and securely "Lockdown" multiple servers within a limited timeframe.

---

## 🌟 Key Features

### 1. One-Click Deployment
Simply executing the `deploy.sh` script in each server folder (`ecom`, `webmail`, `splunk`, `wkst`) automates the entire process from **initial setup to monitoring**.

### 2. Intelligent Context Awareness
*   **Offline Mode**: Automatically detects if internet connectivity is lost, skipping package installations and only applying configuration changes.
*   **OS Detection**: Automatically distinguishes between Ubuntu (`apt`), RHEL/CentOS (`dnf`), and Legacy (`yum`) to execute appropriate commands.
*   **Service Protection**: Identifies essential services for each role (`apache2`, `mysql`, `splunkd`, etc.) and protects them from being terminated.

### 3. Centralized Logging (Splunk Integration)
All clients (Ecom, Webmail, Wkst) automatically **forward system logs to the Splunk server** immediately upon deployment.
*   You can detect intrusion attempts (SSH Brute Force, Sudo abuse, etc.) in real-time centrally.

### 4. Powerful Backdoor Detection (Persistence Hunter)
`audit.sh` can find hidden system backdoors and **automatically neutralize** them.
*   **Detection Items**: Malicious Cron jobs, unknown SUID binaries, UID 0 accounts, SSH keys, Reverse Shell processes, etc.
*   **Auto-Fix**: The `--fix` option immediately removes detected threats.

### 5. Router Hardening (VyOS)
The `wkst/router/` folder contains scripts for VyOS router configuration. Entering your team number will generate configuration commands that can be applied immediately.

---

## 📂 Directory Structure

*   **`ecom/`**: For Ecom Server (Apache, MySQL)
*   **`webmail/`**: For Webmail Server (Postfix, Dovecot)
*   **`splunk/`**: For Splunk Server (Log Receiver)
    *   Includes `configure_receiver.sh` (Log reception setup)
*   **`wkst/`**: For Workstation & Router setup
    *   `router/`: Includes VyOS hardening scripts

---

## 🚀 Workflow

1.  **Splunk Server Setup**
    *   Go to `splunk/` -> `sudo ./configure_receiver.sh` (Enable log reception)
    *   `sudo ./deploy.sh` (Start defense)

2.  **Other Servers Setup (Ecom, Webmail, Wkst)**
    *   Go to each folder -> `sudo ./deploy.sh`
    *   Follow on-screen instructions for basic setup (Password change, etc.).

3.  **Continuous Security Audit**
    *   Periodically run `sudo ./audit.sh --fix` on each server to check for new backdoors.

---

## ⚠️ Emergency Response

What if a service stops working?
1.  **Restart Service**: `systemctl restart <service_name>`
2.  **Reset Firewall**:
    *   Ubuntu (ufw): `sudo ufw disable` or `sudo ufw reset`
    *   Fedora/Oracle (firewalld): `sudo firewall-cmd --set-default-zone=trusted`
3.  **Panic Mode**: Run `sudo ./panic.sh` in each folder to open all ports immediately.
4.  **Restore Backup**: Each script backs up key configuration files before execution. Check the `/root/ccdc_backup_...` folder.