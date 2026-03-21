#!/bin/bash
# ══════════════════════════════════════════════════════════════
#  WordPress Lab Exam Checker (Student Self-Check)
#  curl -sL https://raw.githubusercontent.com/johnwilben/CLDCOMP/main/wordpress-checker.sh | sudo bash
# ══════════════════════════════════════════════════════════════

SCORE=0
MAX=100

# Auto-detect WordPress path
WP_CONFIG=$(find /var/www -name "wp-config.php" 2>/dev/null | head -1)
if [ -n "$WP_CONFIG" ]; then
    WP_DIR=$(dirname "$WP_CONFIG")
else
    WP_DIR="/var/www/html"
fi

# Detect web URL path
DOC_ROOT=$(apache2ctl -S 2>/dev/null | grep -i documentroot | head -1 | sed 's/.*"\(.*\)".*/\1/')
DOC_ROOT="${DOC_ROOT:-/var/www/html}"
WEB_PATH="${WP_DIR#$DOC_ROOT}"
[ -z "$WEB_PATH" ] && WEB_PATH="/"
[[ "$WEB_PATH" != */ ]] && WEB_PATH="$WEB_PATH/"

# IMDSv2 metadata
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --max-time 3 2>/dev/null)
PUB_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" --max-time 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'N/A')
INST_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" --max-time 3 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'N/A')
MAC=$(ip link show 2>/dev/null | grep ether | head -1 | awk '{print $2}')

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

# ── SECTION 1: TROUBLESHOOTING (25 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 1: TROUBLESHOOTING — Fix LAMP (25 pts)        │"
echo "└─────────────────────────────────────────────────────────┘"

[ "$(systemctl is-active apache2)" == "active" ] \
    && check "1.1" "Apache is running" 8 "PASS" \
    || check "1.1" "Apache is not running" 8 "FAIL"

dpkg -l | grep -q "libapache2-mod-php8.3" 2>/dev/null \
    && check "1.2" "libapache2-mod-php8.3 installed" 9 "PASS" \
    || check "1.2" "libapache2-mod-php8.3 missing" 9 "FAIL"

php -m 2>/dev/null | grep -qi "mysqli" \
    && check "1.3" "php8.3-mysql installed" 8 "PASS" \
    || check "1.3" "php8.3-mysql missing" 8 "FAIL"

# ── SECTION 2: DATABASE SETUP (15 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 2: DATABASE SETUP (15 pts)                    │"
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
        && check "2.1" "WordPress database exists — $WP_DB" 5 "PASS" \
        || check "2.1" "Database '$WP_DB' not found" 5 "FAIL"
else
    check "2.1" "wp-config.php not found / DB_NAME missing" 5 "FAIL"
fi

if [ -n "$WP_USER" ] && [ "$WP_USER" != "root" ]; then
    check "2.2" "Dedicated DB user — $WP_USER" 5 "PASS"
elif [ "$WP_USER" == "root" ]; then
    check "2.2" "Using root! Must use dedicated user" 5 "FAIL"
else
    check "2.2" "DB user not detected" 5 "FAIL"
fi

if [ -n "$WP_USER" ] && [ -n "$WP_DB" ]; then
    GRANTS=$(sudo mysql -e "SHOW GRANTS FOR '$WP_USER'@'localhost';" 2>/dev/null | grep -i "$WP_DB")
    [ -n "$GRANTS" ] \
        && check "2.3" "User has grants on database" 5 "PASS" \
        || check "2.3" "No grants found" 5 "FAIL"
else
    check "2.3" "Cannot check grants" 5 "FAIL"
fi

# ── SECTION 3: WORDPRESS INSTALLATION (20 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 3: WORDPRESS INSTALLATION (20 pts)            │"
echo "└─────────────────────────────────────────────────────────┘"

[ -f "$WP_DIR/wp-config.php" ] \
    && check "3.1" "WordPress files present" 5 "PASS" \
    || check "3.1" "WordPress files not found" 5 "FAIL"

if [ -f "$WP_DIR/wp-config.php" ]; then
    grep -q "database_name_here" "$WP_DIR/wp-config.php" 2>/dev/null
    [ $? -ne 0 ] \
        && check "3.2" "wp-config.php configured" 5 "PASS" \
        || check "3.2" "wp-config.php still has defaults!" 5 "FAIL"
else
    check "3.2" "wp-config.php not found" 5 "FAIL"
fi

OWNER=$(stat -c '%U' "$WP_DIR/index.php" 2>/dev/null)
[ "$OWNER" == "www-data" ] \
    && check "3.3" "File ownership = www-data" 5 "PASS" \
    || check "3.3" "Ownership = $OWNER (expected www-data)" 5 "FAIL"

apache2ctl -M 2>/dev/null | grep -q rewrite \
    && check "3.4" "mod_rewrite enabled" 5 "PASS" \
    || check "3.4" "mod_rewrite not enabled" 5 "FAIL"

# ── SECTION 4: CONTENT & PERSONALIZATION (20 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 4: CONTENT & PERSONALIZATION (20 pts)         │"
echo "└─────────────────────────────────────────────────────────┘"

PAGE=$(curl -s --max-time 5 "http://localhost${WEB_PATH}" 2>/dev/null)

SITE_TITLE=$(echo "$PAGE" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | head -1)
if [ -n "$SITE_TITLE" ] && ! echo "$SITE_TITLE" | grep -qi "^wordpress$"; then
    check "4.1" "Site title customized — $SITE_TITLE" 7 "PASS"
elif [ -n "$SITE_TITLE" ]; then
    check "4.1" "Site title is still default 'WordPress'" 7 "FAIL"
else
    check "4.1" "Cannot detect site title" 7 "FAIL"
fi

if [ -n "$WP_DB" ]; then
    POST_COUNT=$(sudo mysql -N -e "SELECT COUNT(*) FROM ${WP_DB}.wp_posts WHERE post_status='publish' AND post_type IN ('post','page') AND post_title NOT IN ('Sample Page','Hello world!');" 2>/dev/null)
    if [ -n "$POST_COUNT" ] && [ "$POST_COUNT" -gt 0 ]; then
        check "4.2" "Custom post/page found ($POST_COUNT)" 7 "PASS"
    else
        check "4.2" "No custom post/page (defaults don't count)" 7 "FAIL"
    fi
else
    check "4.2" "Cannot check posts" 7 "FAIL"
fi

if [ -n "$WP_DB" ]; then
    CONTENT_LEN=$(sudo mysql -N -e "SELECT MAX(CHAR_LENGTH(post_content)) FROM ${WP_DB}.wp_posts WHERE post_status='publish' AND post_type IN ('post','page') AND post_title NOT IN ('Sample Page','Hello world!');" 2>/dev/null)
    if [ -n "$CONTENT_LEN" ] && [ "$CONTENT_LEN" -gt 50 ]; then
        check "4.3" "Post has actual content ($CONTENT_LEN chars)" 6 "PASS"
    else
        check "4.3" "Post content too short or empty" 6 "FAIL"
    fi
else
    check "4.3" "Cannot check content" 6 "FAIL"
fi

# ── SECTION 5: SECURITY & PERMISSIONS (10 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 5: SECURITY & PERMISSIONS (10 pts)            │"
echo "└─────────────────────────────────────────────────────────┘"

CONF_PERM=$(stat -c '%a' "$WP_DIR/wp-config.php" 2>/dev/null)
if [ "$CONF_PERM" == "640" ] || [ "$CONF_PERM" == "644" ] || [ "$CONF_PERM" == "600" ]; then
    check "5.1" "wp-config.php permissions = $CONF_PERM" 5 "PASS"
else
    check "5.1" "wp-config.php = $CONF_PERM (expected 640/644)" 5 "FAIL"
fi

if [ -n "$WP_USER" ] && [ "$WP_USER" != "root" ]; then
    check "5.2" "Not using root for DB" 5 "PASS"
else
    check "5.2" "Using root for DB — security risk!" 5 "FAIL"
fi

# ── SECTION 6: FUNCTIONALITY (10 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 6: FUNCTIONALITY (10 pts)                     │"
echo "└─────────────────────────────────────────────────────────┘"

echo "$PAGE" | grep -qi "wordpress\|wp-content" \
    && check "6.1" "Front page loads" 5 "PASS" \
    || check "6.1" "Front page not loading" 5 "FAIL"

ADMIN=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost${WEB_PATH}wp-login.php" 2>/dev/null)
[ "$ADMIN" -ge 200 ] && [ "$ADMIN" -lt 400 ] \
    && check "6.2" "Admin login accessible — HTTP $ADMIN" 5 "PASS" \
    || check "6.2" "Admin login — HTTP $ADMIN" 5 "FAIL"

# ── FINAL RESULTS ──
echo ""
echo "══════════════════════════════════════════════════════════"
echo "  FINAL RESULTS"
echo "══════════════════════════════════════════════════════════"
echo ""
echo "  Score : $SCORE / $MAX"
echo ""

if [ "$SCORE" -ge 90 ]; then
    echo "  Grade : ⭐ EXCELLENT"
elif [ "$SCORE" -ge 80 ]; then
    echo "  Grade : ✅ VERY GOOD"
elif [ "$SCORE" -ge 70 ]; then
    echo "  Grade : ✅ GOOD"
elif [ "$SCORE" -ge 60 ]; then
    echo "  Grade : ⚠️  NEEDS IMPROVEMENT"
else
    echo "  Grade : ❌ INCOMPLETE"
fi

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Screenshot this output and submit to your instructor."
echo "══════════════════════════════════════════════════════════"
