# CCDC Defense Deployment (Workstation)

Automated defense and hardening scripts for the **Workstation** (Operator PC or spare server).
This package features a **Router (VyOS) Hardening Script** in addition to standard security measures.

## 🚀 Quick Start

Open a terminal and run the following commands:

1. **Grant Execution Permissions**
   ```bash
   chmod +x *.sh
   ```

2. **Run Automated Deployment**
   ```bash
   sudo ./deploy.sh
   ```
   *   Performs initial setup, firewall configuration, service cleanup, and log forwarding.

3. **Backdoor Detection & Removal**
   ```bash
   sudo ./audit.sh --fix
   ```

---

## 📂 File Structure & Description

### 1. Router Hardening (VyOS)
*   **`router/vyos_hardening.sh`**: **(CORE)** Configuration command generator for VyOS routers.
    *   **Usage**: Run `./router/vyos_hardening.sh` and enter your Team Number.
    *   **Features**:
        *   Sets WAN Interface IP.
        *   Creates NAT rules (1:1 NAT).
        *   Creates Firewall rules (Allow only Public IP Pool).
        *   Sets SSH admin keys, etc.
    *   Simply copy the generated commands and paste them into the VyOS console.

### 2. Core Scripts
*   **`deploy.sh`**: Orchestrates the entire defense process.
*   **`vars.sh`**: Server environment variable settings.
*   **`common.sh`**: Common function library (includes log forwarding).

### 3. Functional Scripts
*   **`init_setting.sh`**: User password change and SSH key removal.
*   **`firewall_safe.sh`**: Firewall (ufw) settings.
*   **`service_killer.sh`**: Terminates unnecessary services.
*   **`audit.sh`**: Backdoor detection and removal (supports `--fix`).
*   **`monitor.sh`**: Real-time monitoring dashboard.

---

## 🛠️ Key Features

### 1. Splunk Log Forwarding
When `deploy.sh` runs, this Workstation is also configured to forward system logs to the Splunk server (`172.20.242.20`).

### 2. VyOS Automation
Due to the nature of CCDC competitions, router configuration is complex and prone to errors. The included `vyos_hardening.sh` allows you to simply enter your Team Number, and it scripts the complex NAT and routing settings perfectly. Be sure to utilize this script before configuring the router.

---

## ⚠️ Notes

*   Since Workstations typically use a Graphic User Interface (GUI), ensure that `vars.sh` is configured so that GUI-related processes (Xorg, etc.) are not accidentally blocked (default settings are for servers, so caution is advised).
