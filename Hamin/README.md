# CCDC Defense Toolkit v2.0

Interactive Linux hardening and monitoring scripts for Collegiate Cyber Defense Competition.

## Folder Structure

```
Hamin/
├── ecom/              # Ubuntu 24 - E-commerce Server (iptables)
│   ├── vars.sh        # Ecom-specific config (HTTP, HTTPS, MySQL)
│   ├── deploy.sh      # Main deployment script
│   └── ...            # All hardening scripts
├── webmail/           # Fedora 42 - Mail Server (firewalld)
│   ├── vars.sh        # Webmail-specific config (SMTP, IMAP, POP3)
│   ├── deploy.sh
│   └── ...
├── splunk/            # Oracle Linux 9 - SIEM Server (firewalld)
│   ├── vars.sh        # Splunk-specific config (ports 8000, 9997)
│   ├── deploy.sh
│   └── ...
├── wkst/              # Ubuntu 24 - Workstation (iptables)
│   ├── vars.sh        # Minimal config (SSH only)
│   ├── deploy.sh
│   └── ...
├── GIT_WORKFLOW.md    # Git branch strategy
└── README.md          # This file
```

## Quick Start

```bash
# 1. Clone specific server branch
git clone -b server/ecom --single-branch <repo_url>

# 2. Navigate to server folder
cd Scripts-for-CCDC-2026/Hamin/ecom

# 3. Update Scoreboard IP in vars.sh
nano vars.sh

# 4. Run deployment
chmod +x *.sh
sudo ./deploy.sh
```

## Server Assignments

| Server | OS | Folder | Firewall | Ports |
|--------|-----|--------|----------|-------|
| Ecom | Ubuntu 24 | `ecom/` | ufw | 22, 80, 443, 3306 |
| Webmail | Fedora 42 | `webmail/` | firewalld | 22, 25, 80, 110, 143, 443 |
| Splunk | Oracle 9 | `splunk/` | firewalld | 22, 8000, 8089, 9997 |
| Wkst | Ubuntu 24 | `wkst/` | ufw | 22 |

## Features

- **Interactive Mode**: Confirmation prompts before dangerous actions
- **Dry-Run Mode**: Preview changes without applying (`--dry-run`)
- **IPv6 Support**: Firewall rules for both IPv4 and IPv6
- **Auto-Rollback**: Firewall reverts if SSH access is lost
- **Backdoor Detection**: Audit for persistence mechanisms

## Scripts (in each server folder)

| Script | Purpose |
|--------|---------|
| `deploy.sh` | Main entry point - runs all scripts in sequence |
| `vars.sh` | Server-specific configuration |
| `common.sh` | Shared utilities (prompts, logging, colors) |
| `init_setting.sh` | Password reset, user cleanup, SSH key removal |
| `firewall_safe.sh` | iptables/ip6tables with whitelist rules |
| `service_killer.sh` | Disable risky services |
| `monitor.sh` | Real-time defense dashboard |
| `audit.sh` | Backdoor & persistence detection |
| `rollback.sh` | Restore from backup |
| `panic.sh` | Emergency firewall reset |

## Usage Examples

```bash
# Full interactive deployment
sudo ./deploy.sh

# Preview what would happen (no changes)
sudo ./deploy.sh --dry-run

# Non-interactive (automated)
sudo ./deploy.sh --auto

# Run individual scripts
sudo ./audit.sh --report

# Emergency reset
sudo ./panic.sh
```

## Git Branch Workflow

See [GIT_WORKFLOW.md](GIT_WORKFLOW.md) for detailed branch strategy.

```bash
# Create server branches
git checkout -b server/ecom && git push -u origin server/ecom
git checkout main && git checkout -b server/webmail && git push -u origin server/webmail
git checkout main && git checkout -b server/splunk && git push -u origin server/splunk
```

## Monitor Controls

| Key | Action |
|-----|--------|
| `q` | Quit |
| `p` | Panic mode |
| `r` | Refresh |
| `a` | Run audit |

## Logs

All actions are logged to `/var/log/ccdc/`