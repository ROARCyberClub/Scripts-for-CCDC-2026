# Workstation (Ubuntu 24)

General workstation - ufw-based security scripts

## Quick Start

```bash
chmod +x *.sh
sudo ./deploy.sh
```

## Server Info

| Item | Value |
|------|-------|
| **OS** | Ubuntu 24 |
| **Firewall** | ufw (Ubuntu native) |
| **Services** | SSH only (minimal) |
| **Ports** | 22 (SSH) |

## Features

- **Minimal Attack Surface** - Only SSH allowed
- **User Hardening** - Password reset, suspicious user kick
- **Backdoor Detection** - Audit for persistence mechanisms
- **ufw with auto-rollback** - SSH lockout prevention

## Pre-Competition Checklist

1. Update `SCOREBOARD_IPS` in `vars.sh`
2. Preview with `sudo ./deploy.sh --dry-run`
3. Run `sudo ./deploy.sh`

## Monitor Shortcuts

| Key | Action |
|-----|--------|
| `q` | Quit |
| `p` | Panic (disable firewall) |
| `r` | Refresh |
| `a` | Security audit |

## Notes

- This is a minimal workstation config
- Only SSH is allowed by default
- Add more ports to vars.sh if needed:
  ```bash
  # In firewall_safe.sh or manually:
  sudo ufw allow 80/tcp
  ```
