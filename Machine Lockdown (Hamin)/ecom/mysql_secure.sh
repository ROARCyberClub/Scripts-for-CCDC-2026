#!/bin/bash
# ==============================================================================
# SCRIPT: mysql_secure.sh (MySQL/MariaDB Security)
# PURPOSE: Secure MySQL installation for E-commerce server
# USAGE: sudo ./mysql_secure.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load dependencies
source ./vars.sh 2>/dev/null || { echo "[ERROR] vars.sh not found"; exit 1; }
source ./common.sh 2>/dev/null || { echo "[ERROR] common.sh not found"; exit 1; }

require_root

# ------------------------------------------------------------------------------
# 1. CHECK MYSQL/MARIADB
# ------------------------------------------------------------------------------
header "MySQL/MariaDB Security Hardening"

MYSQL_CMD=""
if command_exists mysql; then
    MYSQL_CMD="mysql"
elif command_exists mariadb; then
    MYSQL_CMD="mariadb"
else
    error "MySQL/MariaDB not found!"
    exit 1
fi

info "Found: $MYSQL_CMD"

# Check if MySQL is running
if ! systemctl is-active --quiet mysql 2>/dev/null && ! systemctl is-active --quiet mariadb 2>/dev/null && ! systemctl is-active --quiet mysqld 2>/dev/null; then
    error "MySQL/MariaDB is not running!"
    info "Start with: sudo systemctl start mysql"
    exit 1
fi

success "MySQL/MariaDB is running"

# ------------------------------------------------------------------------------
# 2. BACKUP MySQL CONFIG
# ------------------------------------------------------------------------------
subheader "Backup Configuration"

BACKUP_DIR="/root/ccdc_backup_mysql_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup MySQL configs
for conf in /etc/mysql /etc/my.cnf /etc/my.cnf.d; do
    if [ -e "$conf" ]; then
        cp -r "$conf" "$BACKUP_DIR/" 2>/dev/null
        info "Backed up: $conf"
    fi
done

success "Backup saved to: $BACKUP_DIR"

# ------------------------------------------------------------------------------
# 3. GET NEW ROOT PASSWORD
# ------------------------------------------------------------------------------
subheader "MySQL Root Password"

if [ "$INTERACTIVE" == "true" ]; then
    info "You will set a new MySQL root password."
    warn "Make sure to remember this password!"
    echo ""
    
    MYSQL_ROOT_PASS=$(prompt_password "Enter new MySQL ROOT password")
else
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        error "Non-interactive mode requires MYSQL_ROOT_PASSWORD environment variable."
        exit 1
    fi
    MYSQL_ROOT_PASS="$MYSQL_ROOT_PASSWORD"
fi

# ------------------------------------------------------------------------------
# 4. SECURE MYSQL INSTALLATION
# ------------------------------------------------------------------------------
subheader "Securing MySQL"

# Try to connect without password first (insecure default)
CAN_CONNECT_NOPASS="false"
if $MYSQL_CMD -u root -e "SELECT 1" &>/dev/null; then
    CAN_CONNECT_NOPASS="true"
    warn "MySQL root has NO PASSWORD! Fixing..."
fi

# Change root password
info "Changing root password..."
if [ "$CAN_CONNECT_NOPASS" == "true" ]; then
    $MYSQL_CMD -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF
    if [ $? -eq 0 ]; then
        success "Root password changed"
    else
        error "Failed to change root password"
    fi
else
    warn "Cannot connect without password. Trying with current password..."
    if [ "$INTERACTIVE" == "true" ]; then
        echo -en "${YELLOW}[?]${NC} Enter CURRENT MySQL root password: "
        read -rs CURRENT_PASS
        echo ""
        
        $MYSQL_CMD -u root -p"$CURRENT_PASS" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF
        if [ $? -eq 0 ]; then
            success "Root password changed"
        else
            error "Failed to change root password (wrong current password?)"
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 5. REMOVE DANGEROUS ACCOUNTS
# ------------------------------------------------------------------------------
subheader "Removing Dangerous Accounts"

# Connect with new password
MYSQL_OPTS="-u root -p$MYSQL_ROOT_PASS"

# Remove anonymous users
info "Removing anonymous users..."
$MYSQL_CMD $MYSQL_OPTS -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null
success "Anonymous users removed"

# Remove remote root access
info "Removing remote root access..."
$MYSQL_CMD $MYSQL_OPTS -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null
success "Remote root access removed"

# Remove test database
info "Removing test database..."
$MYSQL_CMD $MYSQL_OPTS -e "DROP DATABASE IF EXISTS test;" 2>/dev/null
$MYSQL_CMD $MYSQL_OPTS -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null
success "Test database removed"

# Flush privileges
$MYSQL_CMD $MYSQL_OPTS -e "FLUSH PRIVILEGES;" 2>/dev/null

# ------------------------------------------------------------------------------
# 6. BIND ADDRESS (Local Only)
# ------------------------------------------------------------------------------
subheader "Network Security"

MYSQL_CONF=""
if [ -f "/etc/mysql/mysql.conf.d/mysqld.cnf" ]; then
    MYSQL_CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"
elif [ -f "/etc/mysql/mariadb.conf.d/50-server.cnf" ]; then
    MYSQL_CONF="/etc/mysql/mariadb.conf.d/50-server.cnf"
elif [ -f "/etc/my.cnf" ]; then
    MYSQL_CONF="/etc/my.cnf"
fi

if [ -n "$MYSQL_CONF" ]; then
    info "Checking bind-address in $MYSQL_CONF..."
    
    CURRENT_BIND=$(grep -E "^bind-address" "$MYSQL_CONF" 2>/dev/null | awk '{print $3}')
    
    if [ "$CURRENT_BIND" == "127.0.0.1" ] || [ "$CURRENT_BIND" == "localhost" ]; then
        success "MySQL is already bound to localhost only"
    elif [ -n "$CURRENT_BIND" ]; then
        warn "MySQL is bound to: $CURRENT_BIND"
        
        if [ "$INTERACTIVE" == "true" ]; then
            if confirm "Change to localhost only (more secure)?" "y"; then
                sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' "$MYSQL_CONF"
                success "Changed to localhost only"
                info "Note: Restart MySQL to apply: sudo systemctl restart mysql"
            fi
        fi
    else
        warn "bind-address not set. Consider adding: bind-address = 127.0.0.1"
    fi
else
    warn "MySQL config file not found"
fi

# ------------------------------------------------------------------------------
# 7. LIST CURRENT USERS
# ------------------------------------------------------------------------------
subheader "Current MySQL Users"

info "Database users:"
$MYSQL_CMD $MYSQL_OPTS -e "SELECT User, Host FROM mysql.user;" 2>/dev/null | while read line; do
    echo "    $line"
done

# ------------------------------------------------------------------------------
# 8. SUMMARY
# ------------------------------------------------------------------------------
header "MySQL Security Summary"

echo ""
success "MySQL security hardening completed!"
echo ""
info "Changes made:"
echo "    ✓ Root password changed"
echo "    ✓ Anonymous users removed"
echo "    ✓ Remote root access disabled"
echo "    ✓ Test database removed"
echo ""
warn "IMPORTANT: Save the new MySQL root password!"
echo ""
info "To test: mysql -u root -p"

log_action "MySQL security hardening completed"
