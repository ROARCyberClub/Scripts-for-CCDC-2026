# Git Workflow for CCDC 2026 Scripts

## Branch Structure

```
main                    # Stable/production branch
└── Hamin               # Development branch (all scripts)
```

All server scripts (ecom, webmail, splunk, wkst) are maintained in a single branch `Hamin` under the `Machine Lockdown (Hamin)/` directory.

---

## Repository URL

```
https://github.com/ROARCyberClub/Scripts-for-CCDC-2026.git
```

---

## During Competition - Quick Deploy

### Clone and Deploy (All-in-One)

```bash
# Clone the repository
git clone https://github.com/ROARCyberClub/Scripts-for-CCDC-2026.git
cd "Scripts-for-CCDC-2026/Machine Lockdown (Hamin)"

# Switch to Hamin branch
git checkout Hamin
```

### Deploy to Each Server

```bash
# On Ecom Server (Ubuntu 24)
cd ecom && chmod +x *.sh && sudo ./deploy.sh

# On Webmail Server (Fedora 42)
cd webmail && chmod +x *.sh && sudo ./deploy.sh

# On Splunk Server (Oracle 9) - Run configure_receiver.sh FIRST!
cd splunk && chmod +x *.sh
sudo ./configure_receiver.sh
sudo ./deploy.sh

# On Workstation (Ubuntu 24)
cd wkst && chmod +x *.sh && sudo ./deploy.sh
```

---

## Development Workflow

### Push Changes

```bash
cd "Machine Lockdown (Hamin)"
git add .
git commit -m "Your commit message"
git push origin Hamin
```

### Pull Latest Changes

```bash
git pull origin Hamin
```

---

## Directory Structure

```
Machine Lockdown (Hamin)/
├── ecom/           # Ubuntu 24 - E-commerce (Apache, MySQL)
├── webmail/        # Fedora 42 - Mail Server (Postfix, Dovecot)
├── splunk/         # Oracle 9 - SIEM/Log Server
├── wkst/           # Ubuntu 24 - Workstation + VyOS Router scripts
│   └── router/     # VyOS configuration generator
└── README.md       # Main documentation
```

---

## Quick Reference

| Server | OS | Directory | First Command |
|--------|-----|-----------|---------------|
| Ecom | Ubuntu 24 | `ecom/` | `sudo ./deploy.sh` |
| Webmail | Fedora 42 | `webmail/` | `sudo ./deploy.sh` |
| Splunk | Oracle 9 | `splunk/` | `sudo ./configure_receiver.sh` |
| Workstation | Ubuntu 24 | `wkst/` | `sudo ./deploy.sh` |
| VyOS Router | VyOS | `wkst/router/` | `./vyos_hardening.sh` |

---

## Emergency Commands

```bash
# Open all firewall ports (PANIC MODE)
sudo ./panic.sh

# Run backdoor detection and auto-fix
sudo ./audit.sh --fix

# Rollback changes (Splunk only)
sudo ./rollback.sh
```
