# Splunk Server (Oracle Linux 9)

SIEM/Log analysis server - firewalld-based security scripts

## Quick Start

```bash
chmod +x *.sh
sudo ./deploy.sh
```

## Server Info

| Item | Value |
|------|-------|
| **OS** | Oracle Linux 9 |
| **Firewall** | firewalld (native) |
| **Services** | Splunk Enterprise |
| **Ports** | 22(SSH), 8000(Web), 8089(API), 9997(Forwarders) |

## Features

- **Automatic Splunk Port Configuration** - Added on deploy  
- **Splunk Config Backup** - `/opt/splunk/etc/` auto backup  
- **Real-time Monitoring** - Splunk status dashboard  
- **firewalld Support** - Oracle Linux 9 native  

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
| `s` | Restart Splunk |

## Log Collection Setup

To receive logs from other servers:
1. Install Universal Forwarder on Ecom/Webmail servers
2. Configure forwarders to send to port 9997 on this server
