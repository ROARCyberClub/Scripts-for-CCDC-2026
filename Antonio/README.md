# Linux Defaults Scripts
This is scripts for Linux security configurations and detection audit for any compromise and risky default configurations.
### Quick Start
chmod +x ccdc_audit_persist_logging.sh

chmod +x Linux_Defaults/*.sh
### Detection Script
Reports persistence mechanisms like cron jobs, systemd timers, rc scripts, and SSH authorized keys.
It also checks logging and time like peristent jounrals, logrotate, time syncrhonization services.
This is to get ensure there are no missing/misconfigurations within the default Linux systems.
A report is writtn to /var/log/ccdc-audits/.
### Baseline Linux Hardening
This script applies OS-level default security changes by doing the following:
lock down /etc/shadow, /etc/gshadow, etc.

set hardened default umask

enforce 1777 on /tmp, /var/tmp, /dev/shm

disable core dumps

apply non-network kernel hardening sysctls

optionally move SELinux from Permissive → Enforcing
