# CCDC Defense Toolkit v2.0

Interactive Linux hardening and monitoring scripts for Collegiate Cyber Defense Competition.

## Quick Start

```bash
chmod +x *.sh
sudo ./deploy.sh
```

## Features

- **Interactive Mode**: Confirmation prompts before dangerous actions
- **Dry-Run Mode**: Preview changes without applying (`--dry-run`)
- **IPv6 Support**: Firewall rules for both IPv4 and IPv6
- **Auto-Rollback**: Firewall reverts if SSH access is lost
- **Backdoor Detection**: Audit for persistence mechanisms

## Scripts

| Script | Purpose |
|--------|---------|
| `deploy.sh` | Main entry point - runs all scripts in sequence |
| `vars.sh` | Configuration file - edit before running |
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
sudo ./firewall_safe.sh
sudo ./audit.sh --report

# Emergency reset
sudo ./panic.sh
```

## Configuration (vars.sh)

Edit before running:

```bash
SCOREBOARD_IPS=("10.20.30.1")      # Update with real IPs!
ALLOWED_PROTOCOLS=("ssh" "http")   # Services to allow
PROTECTED_SERVICES=("sshd" "nginx") # Don't disable these
TRAP_PORT="1025"                   # Honeypot port
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