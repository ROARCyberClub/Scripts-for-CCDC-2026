## Purpose
Removes default credentials for sysadmin and admin users as well as enumerating other users on the program. Reduces attack surface by moving default management and web ports. Also validades that Splunk is not unnecessarily listening on insecure interfaces.
### linux
execute as root on splunk server
chmod +x splunk-hardening.sh
sudo ./splunk_harden.sh 

#### NOTE: change firewall rules?
- we changed default ports
ufw allow from 172.20.242.0/24 to any port 9997
ufw allow from <YOUR_IP> to any port 8443
- ip of machines allowed to access splunk UI 
ufw deny 8000
ufw deny 8089

### Splunk uf for linux
installs and configures the splunk uf for linux systems, detects server roles, and forwards those application logs to the central splunk server.
run simular as stated above: 
chmod +x Splunk_logging.sh
sudo ./Splunk_logging.sh
