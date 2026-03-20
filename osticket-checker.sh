#!/bin/bash
# ══════════════════════════════════════════════════════════════
#  osTicket Installation Checker (Student Self-Check)
#  Run this INSIDE your EC2 instance:
#    bash osticket-checker.sh
# ══════════════════════════════════════════════════════════════

SCORE=0
MAX=100

# Auto-detect osTicket path
OT_CONFIG=$(find /var/www -name "ost-config.php" 2>/dev/null | head -1)
if [ -n "$OT_CONFIG" ]; then
    OT_DIR=$(dirname "$(dirname "$OT_CONFIG")")
else
    OT_DIR="/var/www/html"
fi

# Detect web URL path (e.g. /osticket/ or /)
DOC_ROOT=$(apache2ctl -S 2>/dev/null | grep -i documentroot | head -1 | sed 's/.*"\(.*\)".*/\1/' )
DOC_ROOT="${DOC_ROOT:-/var/www/html}"
WEB_PATH="${OT_DIR#$DOC_ROOT}"
[ -z "$WEB_PATH" ] && WEB_PATH="/"
[[ "$WEB_PATH" != */ ]] && WEB_PATH="$WEB_PATH/"

PUB_IP=$(curl -s --max-time 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'N/A')
INST_ID=$(curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'N/A')
MAC=$(ip link show 2>/dev/null | grep ether | head -1 | awk '{print $2}')

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  osTicket Installation Checker"
echo "══════════════════════════════════════════════════════════"
echo ""
echo "  ┌───────────────────────────────────────────────────┐"
echo "  │  STUDENT FINGERPRINT (Do NOT alter this section)  │"
echo "  ├───────────────────────────────────────────────────┤"
echo "  │  Instance ID : $INST_ID"
echo "  │  Public IP   : $PUB_IP"
echo "  │  MAC Address : $MAC"
echo "  │  Checked     : $(date)"
echo "  │  Path        : $OT_DIR"
echo "  └───────────────────────────────────────────────────┘"

check() {
    local id="$1"; local desc="$2"; local pts="$3"; local result="$4"
    if [ "$result" == "PASS" ]; then
        SCORE=$((SCORE + pts))
        printf "  ✅  %-4s %-48s %2d/%2d\n" "$id" "$desc" "$pts" "$pts"
    else
        printf "  ❌  %-4s %-48s %2d/%2d\n" "$id" "$desc" "0" "$pts"
    fi
}

# ── SECTION 1: EC2 INSTANCE SETUP (15 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 1: EC2 INSTANCE SETUP (15 pts)                │"
echo "└─────────────────────────────────────────────────────────┘"

OS_VER=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
[[ "$OS_VER" == *"24"*"Ubuntu"* || "$OS_VER" == *"Ubuntu"*"24"* ]] \
    && check "1.1" "Ubuntu 24.04 — $OS_VER" 5 "PASS" \
    || check "1.1" "Ubuntu 24.04 — Got: $OS_VER" 5 "FAIL"

INST=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null)
[ -n "$INST" ] \
    && check "1.2" "Instance type: $INST" 3 "PASS" \
    || check "1.2" "Instance type: (metadata unavailable)" 3 "PASS"

SG_80=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost${WEB_PATH}" 2>/dev/null)
[ "$SG_80" != "000" ] \
    && check "1.3" "Port 80 responding — HTTP $SG_80" 4 "PASS" \
    || check "1.3" "Port 80 not responding" 4 "FAIL"

SS_22=$(ss -tlnp | grep ":22 ")
[ -n "$SS_22" ] \
    && check "1.4" "SSH (port 22) listening" 3 "PASS" \
    || check "1.4" "SSH not listening" 3 "FAIL"

# ── SECTION 2: LAMP STACK (25 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 2: LAMP STACK (25 pts)                        │"
echo "└─────────────────────────────────────────────────────────┘"

[ "$(systemctl is-active apache2)" == "active" ] \
    && check "2.1" "Apache installed and running" 7 "PASS" \
    || check "2.1" "Apache not running" 7 "FAIL"

[ "$(systemctl is-active mysql)" == "active" ] \
    && check "2.2" "MySQL installed and running" 6 "PASS" \
    || check "2.2" "MySQL not running" 6 "FAIL"

PHP_VER=$(php -v 2>/dev/null | head -1)
PHP_MODS=$(php -m 2>/dev/null)
MISSING=""
for mod in mysqli gd imap xml mbstring intl curl zip; do
    echo "$PHP_MODS" | grep -qi "$mod" || MISSING="$MISSING $mod"
done
if echo "$PHP_VER" | grep -qi "8.3" && [ -z "$MISSING" ]; then
    check "2.3" "PHP 8.3 + all required modules" 7 "PASS"
elif [ -n "$PHP_VER" ]; then
    check "2.3" "PHP found, missing:$MISSING" 7 "FAIL"
else
    check "2.3" "PHP not installed" 7 "FAIL"
fi

A_EN=$(systemctl is-enabled apache2 2>/dev/null)
M_EN=$(systemctl is-enabled mysql 2>/dev/null)
[ "$A_EN" == "enabled" ] && [ "$M_EN" == "enabled" ] \
    && check "2.4" "Apache & MySQL enabled on boot" 5 "PASS" \
    || check "2.4" "On boot — apache2=$A_EN mysql=$M_EN" 5 "FAIL"

# ── SECTION 3: DATABASE (15 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 3: DATABASE (15 pts)                          │"
echo "└─────────────────────────────────────────────────────────┘"

DB=$(sudo mysql -e "SHOW DATABASES;" 2>/dev/null | grep -i osticket)
[ -n "$DB" ] \
    && check "3.1" "osTicket database found — $DB" 5 "PASS" \
    || check "3.1" "osTicket database not found" 5 "FAIL"

DB_USER=$(sudo mysql -e "SELECT user FROM mysql.user WHERE user NOT IN ('root','mysql.sys','mysql.session','mysql.infoschema','debian-sys-maint');" 2>/dev/null | tail -n +2)
[ -n "$DB_USER" ] \
    && check "3.2" "Dedicated DB user — $DB_USER" 5 "PASS" \
    || check "3.2" "No dedicated DB user found" 5 "FAIL"

ROOT_AUTH=$(sudo mysql -e "SELECT plugin FROM mysql.user WHERE user='root';" 2>/dev/null | tail -1)
echo "$ROOT_AUTH" | grep -qi "auth_socket\|unix_socket\|caching_sha2" \
    && check "3.3" "MySQL root auth secure ($ROOT_AUTH)" 5 "PASS" \
    || check "3.3" "MySQL root auth — $ROOT_AUTH" 5 "FAIL"

# ── SECTION 4: osTicket INSTALLATION (25 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 4: osTicket INSTALLATION (25 pts)             │"
echo "└─────────────────────────────────────────────────────────┘"

[ -f $OT_DIR/include/ost-config.php ] \
    && check "4.1" "osTicket files present" 5 "PASS" \
    || check "4.1" "osTicket files not found" 5 "FAIL"

OWNER=$(stat -c '%U' $OT_DIR/index.php 2>/dev/null)
[ "$OWNER" == "www-data" ] \
    && check "4.2" "File ownership = www-data" 5 "PASS" \
    || check "4.2" "Ownership = $OWNER (expected www-data)" 5 "FAIL"

VHOST=$(apache2ctl -S 2>/dev/null | grep -i "namevhost\|documentroot" | head -1)
[ -n "$VHOST" ] \
    && check "4.3" "VirtualHost configured" 5 "PASS" \
    || check "4.3" "VirtualHost not detected" 5 "FAIL"

apache2ctl -M 2>/dev/null | grep -q rewrite \
    && check "4.4" "mod_rewrite enabled" 3 "PASS" \
    || check "4.4" "mod_rewrite not enabled" 3 "FAIL"

PAGE=$(curl -s --max-time 5 http://localhost${WEB_PATH} 2>/dev/null)
echo "$PAGE" | grep -qi "osticket\|helpdesk\|support\|ticket" \
    && check "4.5" "osTicket installer completed (app loads)" 5 "PASS" \
    || check "4.5" "osTicket not loading" 5 "FAIL"

CONF_PERM=$(stat -c '%a' $OT_DIR/include/ost-config.php 2>/dev/null)
[ "$CONF_PERM" == "644" ] \
    && check "4.6" "ost-config.php permissions = 0644" 2 "PASS" \
    || check "4.6" "ost-config.php = $CONF_PERM (expected 644)" 2 "FAIL"

# ── SECTION 5: POST-INSTALL SECURITY (10 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 5: POST-INSTALL SECURITY (10 pts)             │"
echo "└─────────────────────────────────────────────────────────┘"

[ ! -d $OT_DIR/setup ] \
    && check "5.1" "/setup/ directory removed" 5 "PASS" \
    || check "5.1" "/setup/ directory still exists!" 5 "FAIL"

[ "$CONF_PERM" == "644" ] || [ "$CONF_PERM" == "444" ] \
    && check "5.2" "ost-config.php locked ($CONF_PERM)" 3 "PASS" \
    || check "5.2" "ost-config.php not locked ($CONF_PERM)" 3 "FAIL"

echo "$ROOT_AUTH" | grep -qi "auth_socket\|unix_socket\|caching_sha2" \
    && check "5.3" "MySQL auth secure" 2 "PASS" \
    || check "5.3" "MySQL auth weak" 2 "FAIL"

# ── SECTION 6: FUNCTIONALITY (10 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 6: FUNCTIONALITY (10 pts)                     │"
echo "└─────────────────────────────────────────────────────────┘"

echo "$PAGE" | grep -qi "osticket\|helpdesk\|support\|ticket" \
    && check "6.1" "Client portal loads" 5 "PASS" \
    || check "6.1" "Client portal not loading" 5 "FAIL"

ADMIN=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost${WEB_PATH}scp/ 2>/dev/null)
[ "$ADMIN" -ge 200 ] && [ "$ADMIN" -lt 400 ] \
    && check "6.2" "Admin panel (/scp/) accessible — $ADMIN" 5 "PASS" \
    || check "6.2" "Admin panel (/scp/) — HTTP $ADMIN" 5 "FAIL"

# ── FINAL RESULTS ──
echo ""
echo "══════════════════════════════════════════════════════════"
echo "  FINAL RESULTS"
echo "══════════════════════════════════════════════════════════"
echo ""
echo "  Score : $SCORE / $MAX"
echo ""

if [ "$SCORE" -ge 90 ]; then
    echo "  Grade : ⭐ EXCELLENT — Ready for use"
elif [ "$SCORE" -ge 80 ]; then
    echo "  Grade : ✅ VERY GOOD — Minor improvements needed"
elif [ "$SCORE" -ge 70 ]; then
    echo "  Grade : ✅ GOOD — Some issues to address"
elif [ "$SCORE" -ge 60 ]; then
    echo "  Grade : ⚠️  NEEDS IMPROVEMENT — Significant gaps"
else
    echo "  Grade : ❌ INCOMPLETE — Redo required"
fi

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Screenshot this output and submit to your instructor."
echo "══════════════════════════════════════════════════════════"
