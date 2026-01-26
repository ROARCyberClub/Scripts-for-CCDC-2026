# CCDC Defense Deployment (Ecom Server)

Automated defense and hardening scripts for the **Ecom Server** (Ubuntu/Apache/MySQL).
This package is designed to quickly implement essential security measures, remove backdoors, and provide real-time monitoring in a CCDC competition environment.

## 🚀 Quick Start

Open a terminal and run the following commands:

1. **Grant Execution Permissions**
   ```bash
   chmod +x *.sh
   ```

2. **Run Automated Deployment (Recommended)**
   ```bash
   sudo ./deploy.sh
   ```
   *   This executes **initial setup, firewall configuration, service cleanup, and log forwarding** based on `vars.sh`.
   *   You can choose to proceed interactively via the menu.

3. **Backdoor Detection & Removal**
   ```bash
   # Generate detection report
   sudo ./audit.sh --report

   # [CAUTION] Automatically remove detected backdoors
   sudo ./audit.sh --fix
   ```

---

## 📂 File Structure & Description

### 1. Core Scripts
*   **`deploy.sh`**: The control tower that orchestrates the entire defense process. It detects internet connectivity to operate in offline mode if necessary and runs other scripts sequentially.
*   **`vars.sh`**: **(IMPORTANT)** The server's environment variable configuration file.
    *   `PROTECTED_SERVICES`: List of services that must not be killed (e.g., `apache2`, `mysql`).
    *   `SPLUNK_SERVER_IP`: IP of the Splunk server to forward logs to (`172.20.242.20`).
    *   `ALLOWED_PROTOCOLS`: List of allowed ports.
*   **`common.sh`**: A common function library. Includes the log forwarding function (`setup_splunk_forwarding`).

### 2. Functional Scripts
*   **`init_setting.sh`**: Performs initial hardening.
    *   Changes passwords for all users (except the current admin).
    *   Removes SSH `authorized_keys` (eliminates key-based backdoors).
    *   Backs up configuration files.
*   **`firewall_safe.sh`**: Configures the firewall (iptables/ufw).
    *   Applies whitelist-based blocking policies.
    *   Sets up honeypot trap ports.
*   **`service_killer.sh`**: Terminates unnecessary services.
    *   Services listed in `PROTECTED_SERVICES` in `vars.sh` are preserved.
*   **`audit.sh`**: System security audit tool.
    *   Checks Cron, SUID, processes, temporary directories, etc.
    *   Use the `--fix` option to automatically neutralize emerging threats.
*   **`monitor.sh`**: Real-time defense dashboard.

---

## 🛠️ Key Features

### 1. Splunk Log Forwarding
When `deploy.sh` is executed, it automatically configures `rsyslog` to forward system logs (`syslog`) to the Splunk server (`172.20.242.20`).
*   Config File: `/etc/rsyslog.d/99-ccdc-forward.conf`
*   Target Port: UDP 514

### 2. Offline Mode Support
The scripts automatically detect closed network environments where external Yum/Apt repositories are inaccessible.
*   If there is no internet connection, package installation steps are skipped, and only configuration changes are applied to prevent errors.

### 3. Service Protection
Safeguards are in place to ensure that Ecom's core services (`apache2`/`httpd` and `mysql`/`mariadb`) are not accidentally terminated.
*   You can add/remove protected services in the `vars.sh` file.

---

## ⚠️ Notes

*   **Password Change**: The password entered during `init_setting.sh` applies to **ALL users**. Make sure to remember it.
*   **Audit Fix**: `sudo ./audit.sh --fix` performs powerful actions. It might mistakenly identify legitimate Cron jobs or files as threats, so please verify with `--report` first if possible.
*   **Recovery**: Key files are backed up to a backup directory before any configuration changes. You can restore from there if issues arise.
