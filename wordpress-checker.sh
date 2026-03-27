#!/bin/bash
# ══════════════════════════════════════════════════════════════
#  WordPress Lab Exam Checker
#  curl -sL https://raw.githubusercontent.com/johnwilben/CLDCOMP/main/wordpress-checker.sh | sudo bash
# ══════════════════════════════════════════════════════════════

SCORE=0
MAX=80

# Auto-detect WordPress path
WP_CONFIG=$(find /var/www -name "wp-config.php" 2>/dev/null | head -1)
if [ -n "$WP_CONFIG" ]; then
    WP_DIR=$(dirname "$WP_CONFIG")
else
    WP_DIR="/var/www/html"
fi

DOC_ROOT=$(apache2ctl -S 2>/dev/null | grep -i documentroot | head -1 | sed 's/.*"\(.*\)".*/\1/')
DOC_ROOT="${DOC_ROOT:-/var/www/html}"
WEB_PATH="${WP_DIR#$DOC_ROOT}"
[ -z "$WEB_PATH" ] && WEB_PATH="/"
[[ "$WEB_PATH" != */ ]] && WEB_PATH="$WEB_PATH/"

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --max-time 3 2>/dev/null)
PUB_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" --max-time 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'N/A')
INST_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" --max-time 3 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'N/A')
MAC=$(ip link show 2>/dev/null | grep ether | head -1 | awk '{print $2}')
SG_IDS=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" --max-time 3 http://169.254.169.254/latest/meta-data/security-groups 2>/dev/null || echo 'N/A')

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  WordPress Lab Exam Checker"
echo "══════════════════════════════════════════════════════════"
echo ""
echo "  ┌───────────────────────────────────────────────────┐"
echo "  │  STUDENT FINGERPRINT (Do NOT alter this section)  │"
echo "  ├───────────────────────────────────────────────────┤"
echo "  │  Instance ID : $INST_ID"
echo "  │  Public IP   : $PUB_IP"
echo "  │  MAC Address : $MAC"
echo "  │  Checked     : $(date)"
echo "  │  WP Path     : $WP_DIR"
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

# ── SECTION 1: EC2 SETUP + SECURITY GROUP (10 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 1: EC2 SETUP (8 pts)                          │"
echo "└─────────────────────────────────────────────────────────┘"

[ -n "$INST_ID" ] && [ "$INST_ID" != "N/A" ] \
    && check "1.1" "EC2 instance running — $INST_ID" 3 "PASS" \
    || check "1.1" "EC2 instance not detected" 3 "FAIL"

SS_22=$(ss -tlnp | grep ":22 ")
[ -n "$SS_22" ] \
    && check "1.2" "SSH (port 22) listening" 2 "PASS" \
    || check "1.2" "SSH not listening" 2 "FAIL"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost/" 2>/dev/null)
[ "$HTTP_CODE" != "000" ] \
    && check "1.3" "HTTP (port 80) responding — $HTTP_CODE" 3 "PASS" \
    || check "1.3" "HTTP not responding" 3 "FAIL"

# ── SECTION 2: TROUBLESHOOTING (25 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 2: TROUBLESHOOTING — Fix LAMP (20 pts)        │"
echo "└─────────────────────────────────────────────────────────┘"

[ "$(systemctl is-active apache2)" == "active" ] \
    && check "2.1" "Apache is running" 7 "PASS" \
    || check "2.1" "Apache is not running" 7 "FAIL"

dpkg -l 2>/dev/null | grep -q "ii.*libapache2-mod-php8.3" \
    && check "2.2" "libapache2-mod-php8.3 installed" 7 "PASS" \
    || check "2.2" "libapache2-mod-php8.3 missing" 7 "FAIL"

php -m 2>/dev/null | grep -qi "mysqli" \
    && check "2.3" "php8.3-mysql installed" 6 "PASS" \
    || check "2.3" "php8.3-mysql missing" 6 "FAIL"

# ── SECTION 3: DATABASE SETUP (15 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 3: DATABASE SETUP (12 pts)                    │"
echo "└─────────────────────────────────────────────────────────┘"

WP_DB=""
WP_USER=""
if [ -f "$WP_DIR/wp-config.php" ]; then
    WP_DB=$(grep "DB_NAME" "$WP_DIR/wp-config.php" | cut -d"'" -f4)
    WP_USER=$(grep "DB_USER" "$WP_DIR/wp-config.php" | cut -d"'" -f4)
fi

if [ -n "$WP_DB" ]; then
    DB_EXISTS=$(sudo mysql -e "SHOW DATABASES;" 2>/dev/null | grep -w "$WP_DB")
    [ -n "$DB_EXISTS" ] \
        && check "3.1" "WordPress database exists — $WP_DB" 4 "PASS" \
        || check "3.1" "Database '$WP_DB' not found" 4 "FAIL"
else
    check "3.1" "wp-config.php not found / DB_NAME missing" 4 "FAIL"
fi

if [ -n "$WP_USER" ] && [ "$WP_USER" != "root" ]; then
    check "3.2" "Dedicated DB user — $WP_USER" 4 "PASS"
elif [ "$WP_USER" == "root" ]; then
    check "3.2" "Using root! Must use dedicated user" 4 "FAIL"
else
    check "3.2" "DB user not detected" 4 "FAIL"
fi

if [ -n "$WP_USER" ] && [ -n "$WP_DB" ]; then
    GRANTS=$(sudo mysql -e "SHOW GRANTS FOR '$WP_USER'@'localhost';" 2>/dev/null | grep -i "$WP_DB")
    [ -n "$GRANTS" ] \
        && check "3.3" "User has grants on database" 4 "PASS" \
        || check "3.3" "No grants found" 4 "FAIL"
else
    check "3.3" "Cannot check grants" 4 "FAIL"
fi

# ── SECTION 4: WORDPRESS INSTALLATION (20 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 4: WORDPRESS INSTALLATION (16 pts)            │"
echo "└─────────────────────────────────────────────────────────┘"

[ -f "$WP_DIR/wp-config.php" ] \
    && check "4.1" "WordPress files present" 4 "PASS" \
    || check "4.1" "WordPress files not found" 4 "FAIL"

if [ -f "$WP_DIR/wp-config.php" ]; then
    grep -q "database_name_here" "$WP_DIR/wp-config.php" 2>/dev/null
    [ $? -ne 0 ] \
        && check "4.2" "wp-config.php configured" 4 "PASS" \
        || check "4.2" "wp-config.php still has defaults!" 4 "FAIL"
else
    check "4.2" "wp-config.php not found" 4 "FAIL"
fi

OWNER=$(stat -c '%U' "$WP_DIR/index.php" 2>/dev/null)
[ "$OWNER" == "www-data" ] \
    && check "4.3" "File ownership = www-data" 4 "PASS" \
    || check "4.3" "Ownership = $OWNER (expected www-data)" 4 "FAIL"

apache2ctl -M 2>/dev/null | grep -q rewrite \
    && check "4.4" "mod_rewrite enabled" 4 "PASS" \
    || check "4.4" "mod_rewrite not enabled" 4 "FAIL"

# ── SECTION 5: CONTENT & PERSONALIZATION (15 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 5: CONTENT & PERSONALIZATION (12 pts)         │"
echo "└─────────────────────────────────────────────────────────┘"

PAGE=$(curl -s --max-time 5 "http://localhost${WEB_PATH}" 2>/dev/null)

SITE_TITLE=$(echo "$PAGE" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | head -1)
if [ -n "$SITE_TITLE" ] && ! echo "$SITE_TITLE" | grep -qi "^wordpress$"; then
    check "5.1" "Site title customized — $SITE_TITLE" 4 "PASS"
elif [ -n "$SITE_TITLE" ]; then
    check "5.1" "Site title is still default 'WordPress'" 4 "FAIL"
else
    check "5.1" "Cannot detect site title" 4 "FAIL"
fi

if [ -n "$WP_DB" ]; then
    POST_COUNT=$(sudo mysql -N -e "SELECT COUNT(*) FROM ${WP_DB}.wp_posts WHERE post_status='publish' AND post_type IN ('post','page') AND post_title NOT IN ('Sample Page','Hello world!');" 2>/dev/null)
    if [ -n "$POST_COUNT" ] && [ "$POST_COUNT" -gt 0 ]; then
        check "5.2" "Custom post/page found ($POST_COUNT)" 4 "PASS"
    else
        check "5.2" "No custom post/page (defaults don't count)" 4 "FAIL"
    fi
else
    check "5.2" "Cannot check posts" 4 "FAIL"
fi

if [ -n "$WP_DB" ]; then
    CONTENT_LEN=$(sudo mysql -N -e "SELECT MAX(CHAR_LENGTH(post_content)) FROM ${WP_DB}.wp_posts WHERE post_status='publish' AND post_type IN ('post','page') AND post_title NOT IN ('Sample Page','Hello world!');" 2>/dev/null)
    if [ -n "$CONTENT_LEN" ] && [ "$CONTENT_LEN" -gt 50 ]; then
        check "5.3" "Post has content ($CONTENT_LEN chars)" 4 "PASS"
    else
        check "5.3" "Post content too short or empty" 4 "FAIL"
    fi
else
    check "5.3" "Cannot check content" 4 "FAIL"
fi

# ── SECTION 6: SECURITY & PERMISSIONS (5 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 6: SECURITY & PERMISSIONS (4 pts)             │"
echo "└─────────────────────────────────────────────────────────┘"

CONF_PERM=$(stat -c '%a' "$WP_DIR/wp-config.php" 2>/dev/null)
if [ "$CONF_PERM" == "640" ] || [ "$CONF_PERM" == "644" ] || [ "$CONF_PERM" == "600" ]; then
    check "6.1" "wp-config.php permissions = $CONF_PERM" 2 "PASS"
else
    check "6.1" "wp-config.php = $CONF_PERM (expected 640/644)" 2 "FAIL"
fi

if [ -n "$WP_USER" ] && [ "$WP_USER" != "root" ]; then
    check "6.2" "Not using root for DB" 2 "PASS"
else
    check "6.2" "Using root for DB — security risk!" 2 "FAIL"
fi

# ── SECTION 7: FUNCTIONALITY (10 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 7: FUNCTIONALITY (8 pts)                      │"
echo "└─────────────────────────────────────────────────────────┘"

echo "$PAGE" | grep -qi "wordpress\|wp-content" \
    && check "7.1" "Front page loads" 4 "PASS" \
    || check "7.1" "Front page not loading" 4 "FAIL"

ADMIN=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost${WEB_PATH}wp-login.php" 2>/dev/null)
[ "$ADMIN" -ge 200 ] && [ "$ADMIN" -lt 400 ] \
    && check "7.2" "Admin login accessible — HTTP $ADMIN" 4 "PASS" \
    || check "7.2" "Admin login — HTTP $ADMIN" 4 "FAIL"

# ── FINAL RESULTS ──
echo ""
echo "══════════════════════════════════════════════════════════"
echo "  FINAL RESULTS"
echo "══════════════════════════════════════════════════════════"
echo ""
echo "  Score : $SCORE / $MAX"
echo "  (Security Group checker on CloudShell: 20 pts)"
echo "  Combined Total: $SCORE + SG score / 100"
echo ""

if [ "$SCORE" -ge 72 ]; then
    echo "  Grade : ⭐ EXCELLENT (with perfect SG = 92+)"
elif [ "$SCORE" -ge 64 ]; then
    echo "  Grade : ✅ VERY GOOD (with perfect SG = 84+)"
elif [ "$SCORE" -ge 56 ]; then
    echo "  Grade : ✅ GOOD (with perfect SG = 76+)"
elif [ "$SCORE" -ge 48 ]; then
    echo "  Grade : ⚠️  NEEDS IMPROVEMENT"
else
    echo "  Grade : ❌ INCOMPLETE"
fi

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Screenshot this output and submit to your instructor."
echo "══════════════════════════════════════════════════════════"
