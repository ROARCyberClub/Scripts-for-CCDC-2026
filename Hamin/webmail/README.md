# Webmail Server (Fedora 42)

Mail server (Postfix/Dovecot) - firewalld-based security scripts

## Quick Start

```bash
chmod +x *.sh
sudo ./deploy.sh
```

## Server Info

| Item | Value |
|------|-------|
| **OS** | Fedora 42 |
| **Firewall** | firewalld (native) |
| **Services** | Postfix, Dovecot, Roundcube |
| **Ports** | 22(SSH), 25(SMTP), 80(HTTP), 110(POP3), 143(IMAP), 443(HTTPS) |

## Features

- **Automatic Mail Port Configuration** - SMTP, IMAP, POP3 on deploy
- **Mail Config Backup** - /etc/postfix, /etc/dovecot auto backup
- **Real-time Monitoring** - Mail service status dashboard
- **firewalld Support** - Fedora native

## Pre-Competition Checklist

1. Update `SCOREBOARD_IPS` in `vars.sh`
2. Preview with `sudo ./deploy.sh --dry-run`
3. Run `sudo ./deploy.sh`

## Monitor Shortcuts

| Key | Action |
|-----|--------|
| `q` | Quit |
| `p` | Panic (open firewall) |
| `r` | Refresh |
| `a` | Security audit |
| `m` | Restart mail services |

## Secure Mail Ports (Optional)

If you need secure mail ports, add manually:
```bash
sudo firewall-cmd --permanent --add-port=465/tcp   # SMTPS
sudo firewall-cmd --permanent --add-port=587/tcp   # Submission
sudo firewall-cmd --permanent --add-port=993/tcp   # IMAPS
sudo firewall-cmd --permanent --add-port=995/tcp   # POP3S
sudo firewall-cmd --reload
```
