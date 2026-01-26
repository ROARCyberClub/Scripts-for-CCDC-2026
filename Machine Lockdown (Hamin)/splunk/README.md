# CCDC Defense Deployment (Splunk Server)

Automated defense and hardening scripts for the **Splunk Server**.
Since this server plays a crucial role in collecting logs from other clients (Ecom, Webmail, Wkst), it contains special configurations.

## 🚀 Quick Start

Open a terminal and run the following commands in order:

1. **Grant Execution Permissions**
   ```bash
   chmod +x *.sh
   ```

2. **Configure Log Reception (Run this FIRST!)**
   ```bash
   sudo ./configure_receiver.sh
   ```
   *   This script configures `rsyslog` to allow the Splunk server to receive Syslogs from other servers via **UDP 514** and opens the firewall.

3. **Run Automated Deployment**
   ```bash
   sudo ./deploy.sh
   ```
   *   Performs initial security setup, firewall configuration (allows Splunk ports), and service cleanup.

4. **Backdoor Detection & Removal**
   ```bash
   sudo ./audit.sh --fix
   ```

---

## 📂 File Structure & Description

### 1. Splunk-Specific Scripts
*   **`configure_receiver.sh`**: **(CORE)** Enables the log receiving capability.
    *   Modifies `/etc/rsyslog.conf`: Enables `imudp` and `imtcp` modules.
    *   Opens Firewall: UDP/TCP 514 (Syslog).
    *   If this is not run, you cannot receive logs from other servers.

### 2. Core Scripts
*   **`deploy.sh`**: Orchestrates the entire defense process.
*   **`vars.sh`**: **(IMPORTANT)** Server environment variable settings.
    *   `PROTECTED_SERVICES`: configured to prevent Splunk services (e.g., `splunk`, `splunkd`) from being killed.
    *   `SPLUNK_SYSLOG_PORT`: Defines the log reception port (514).
    *   `SPLUNK_WEB_PORT`, `SPLUNK_FORWARDER_PORT`, etc., define management ports.

### 3. Functional Scripts
*   **`init_setting.sh`**: Initial hardening.
    *   Password change, SSH key removal.
    *   **SSH hardening**: Disables root login, limits auth attempts.
*   **`firewall_safe.sh`**: Firewall settings.
    *   Automatically allows Splunk Web (8000), Forwarder (9997), and Mgmt (8089) ports.
*   **`service_killer.sh`**: Terminates unnecessary services (excluding Splunk services).
*   **`audit.sh`**: Backdoor detection and removal (supports `--fix`).
*   **`monitor.sh`**: Real-time defense dashboard.

---

## 🛠️ Key Features

### 1. Log Receiver
The Splunk server acts as the "eyes" of the defense team.
`configure_receiver.sh` switches the standard Linux `rsyslog` to reception mode, allowing it to ingest system logs from clients without needing separate Splunk Forwarder installations.

### 2. Splunk Service Protection
When `service_killer.sh` runs, the `PROTECTED_SERVICES` list in `vars.sh` ensures that the Splunk daemon (`splunkd`) is safely protected. This prevents security tools from accidentally killing the security monitoring server.

### 3. Offline Mode Support
It operates safely by focusing on configuration file changes even when internet connectivity is lost.

---

## ⚠️ Notes

*   **Log File Location**: Received logs are stored in `/var/log/syslog` (Ubuntu) or `/var/log/messages` (RHEL), or separated into files depending on `rsyslog` config. You must configure Splunk Web to monitor these files (`Data Inputs -> Files & Directories`).
