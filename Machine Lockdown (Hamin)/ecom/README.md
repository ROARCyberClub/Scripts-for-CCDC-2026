# Ecom Server (Ubuntu 24)

E-commerce web server - ufw-based security scripts

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
| **Services** | Apache/Nginx, MySQL, PHP |
| **Ports** | 22(SSH), 80(HTTP), 443(HTTPS), 3306(MySQL) |

## Features

- **Web Server Protection** - Apache/Nginx, PHP-FPM
- **Database Backup** - /etc/mysql, /var/lib/mysql
- **Real-time Monitoring** - Web service status dashboard
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
| `w` | Restart web services |

## UFW Commands Reference

```bash
# View status
sudo ufw status numbered

# Add port
sudo ufw allow 8080/tcp

# Remove rule
sudo ufw delete allow 8080/tcp

# Reload
sudo ufw reload
```
