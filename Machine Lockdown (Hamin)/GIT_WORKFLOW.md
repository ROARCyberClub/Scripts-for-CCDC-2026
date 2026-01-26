# Git Branch Strategy for CCDC Scripts

## Branch Structure

```
main (or master)
├── server/ecom      # Ubuntu 24 - E-commerce
├── server/webmail   # Fedora 42 - Mail server
└── server/splunk    # Oracle 9 - SIEM/Logs
```

## Setup Commands

```bash
# Create and push server-specific branches
git checkout -b server/ecom
git add ecom/
git commit -m "Add Ecom server scripts"
git push -u origin server/ecom

git checkout main
git checkout -b server/webmail
git add webmail/
git commit -m "Add Webmail server scripts"
git push -u origin server/webmail

git checkout main
git checkout -b server/splunk
git add splunk/
git commit -m "Add Splunk server scripts"
git push -u origin server/splunk
```

## During Competition

### Clone specific server branch:
```bash
# On Ecom server (Ubuntu 24)
git clone -b server/ecom --single-branch <repo_url>
cd Scripts-for-CCDC-2026/Hamin/ecom
sudo ./deploy.sh

# On Webmail server (Fedora 42)
git clone -b server/webmail --single-branch <repo_url>
cd Scripts-for-CCDC-2026/Hamin/webmail
sudo ./deploy.sh

# On Splunk server (Oracle 9)
git clone -b server/splunk --single-branch <repo_url>
cd Scripts-for-CCDC-2026/Hamin/splunk
sudo ./deploy.sh
```

## Updating Scripts

### Update common scripts across all branches:
```bash
# Make changes in main
git checkout main
# Edit common.sh, deploy.sh, etc.
git commit -am "Update common scripts"

# Merge to each server branch
git checkout server/ecom && git merge main
git checkout server/webmail && git merge main
git checkout server/splunk && git merge main
```

### Update server-specific config:
```bash
git checkout server/ecom
# Edit ecom/vars.sh
git commit -am "Update Ecom config"
git push
```

## Quick Reference

| Server | Branch | OS | Command |
|--------|--------|-----|---------|
| Ecom | `server/ecom` | Ubuntu 24 | `git clone -b server/ecom ...` |
| Webmail | `server/webmail` | Fedora 42 | `git clone -b server/webmail ...` |
| Splunk | `server/splunk` | Oracle 9 | `git clone -b server/splunk ...` |
