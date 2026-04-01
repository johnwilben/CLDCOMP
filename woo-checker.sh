#!/bin/bash
echo ""
echo "══════════════════════════════════════════════════════════"
echo "  WooCommerce Store Checker"
echo "══════════════════════════════════════════════════════════"

SCORE=0
MAX=100

WP_DIR="/var/www/html"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --max-time 3 2>/dev/null)
PUB_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" --max-time 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'N/A')
INST_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" --max-time 3 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'N/A')

echo ""
echo "  ┌───────────────────────────────────────────────────┐"
echo "  │  GROUP FINGERPRINT                                │"
echo "  ├───────────────────────────────────────────────────┤"
echo "  │  Instance ID : $INST_ID"
echo "  │  Public IP   : $PUB_IP"
echo "  │  Checked     : $(date)"
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

# ── SECTION 1: EC2 + LAMP (15 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 1: EC2 + LAMP SETUP (15 pts)                  │"
echo "└─────────────────────────────────────────────────────────┘"

[ "$(systemctl is-active apache2)" == "active" ] \
    && check "1.1" "Apache is running" 5 "PASS" \
    || check "1.1" "Apache is not running" 5 "FAIL"

php -m 2>/dev/null | grep -qi "mysqli" \
    && check "1.2" "PHP MySQL extension installed" 5 "PASS" \
    || check "1.2" "PHP MySQL extension missing" 5 "FAIL"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost/" 2>/dev/null)
[ "$HTTP_CODE" != "000" ] \
    && check "1.3" "HTTP responding — $HTTP_CODE" 5 "PASS" \
    || check "1.3" "HTTP not responding" 5 "FAIL"

# ── SECTION 2: RDS CONNECTION (25 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 2: RDS CONNECTION (25 pts)                    │"
echo "└─────────────────────────────────────────────────────────┘"

WP_DB=""
WP_USER=""
WP_HOST=""
if [ -f "$WP_DIR/wp-config.php" ]; then
    WP_DB=$(grep "DB_NAME" "$WP_DIR/wp-config.php" | cut -d"'" -f4)
    WP_USER=$(grep "DB_USER" "$WP_DIR/wp-config.php" | cut -d"'" -f4)
    WP_HOST=$(grep "DB_HOST" "$WP_DIR/wp-config.php" | cut -d"'" -f4)
fi

[ -f "$WP_DIR/wp-config.php" ] \
    && check "2.1" "wp-config.php exists" 5 "PASS" \
    || check "2.1" "wp-config.php not found" 5 "FAIL"

if echo "$WP_HOST" | grep -q "rds.amazonaws.com"; then
    check "2.2" "Connected to RDS endpoint" 10 "PASS"
elif [ "$WP_HOST" == "localhost" ]; then
    check "2.2" "Still using localhost — should be RDS!" 10 "FAIL"
else
    check "2.2" "DB host: $WP_HOST (expected RDS endpoint)" 10 "FAIL"
fi

if [ -n "$WP_HOST" ] && [ -n "$WP_DB" ]; then
    mysql -h "$WP_HOST" -u "$WP_USER" -p"$(grep "DB_PASSWORD" "$WP_DIR/wp-config.php" | cut -d"'" -f4)" -e "SELECT 1;" "$WP_DB" > /dev/null 2>&1
    [ $? -eq 0 ] \
        && check "2.3" "Database connection successful" 10 "PASS" \
        || check "2.3" "Cannot connect to database" 10 "FAIL"
else
    check "2.3" "Cannot test connection" 10 "FAIL"
fi

# ── SECTION 3: WORDPRESS (15 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 3: WORDPRESS INSTALLATION (15 pts)            │"
echo "└─────────────────────────────────────────────────────────┘"

[ -f "$WP_DIR/wp-config.php" ] && ! grep -q "database_name_here" "$WP_DIR/wp-config.php" 2>/dev/null \
    && check "3.1" "WordPress configured" 5 "PASS" \
    || check "3.1" "WordPress not configured" 5 "FAIL"

OWNER=$(stat -c '%U' "$WP_DIR/index.php" 2>/dev/null)
[ "$OWNER" == "www-data" ] \
    && check "3.2" "File ownership = www-data" 5 "PASS" \
    || check "3.2" "Ownership = $OWNER (expected www-data)" 5 "FAIL"

PAGE=$(curl -s --max-time 5 "http://localhost/" 2>/dev/null)
echo "$PAGE" | grep -qi "wordpress\|wp-content\|woocommerce" \
    && check "3.3" "WordPress front page loads" 5 "PASS" \
    || check "3.3" "Front page not loading" 5 "FAIL"

# ── SECTION 4: WOOCOMMERCE (25 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 4: WOOCOMMERCE STORE (25 pts)                │"
echo "└─────────────────────────────────────────────────────────┘"

[ -d "$WP_DIR/wp-content/plugins/woocommerce" ] \
    && check "4.1" "WooCommerce plugin installed" 5 "PASS" \
    || check "4.1" "WooCommerce not installed" 5 "FAIL"

WC_ACTIVE=$(sudo -u www-data php -r "
require '$WP_DIR/wp-load.php';
echo is_plugin_active('woocommerce/woocommerce.php') ? 'yes' : 'no';
" 2>/dev/null)
[ "$WC_ACTIVE" == "yes" ] \
    && check "4.2" "WooCommerce activated" 5 "PASS" \
    || check "4.2" "WooCommerce not activated" 5 "FAIL"

if [ -n "$WP_DB" ] && [ -n "$WP_HOST" ]; then
    WP_PASS=$(grep "DB_PASSWORD" "$WP_DIR/wp-config.php" | cut -d"'" -f4)
    PRODUCT_COUNT=$(mysql -h "$WP_HOST" -u "$WP_USER" -p"$WP_PASS" -N -e "SELECT COUNT(*) FROM ${WP_DB}.wp_posts WHERE post_type='product' AND post_status='publish';" 2>/dev/null)
    if [ -n "$PRODUCT_COUNT" ] && [ "$PRODUCT_COUNT" -ge 3 ]; then
        check "4.3" "At least 3 products ($PRODUCT_COUNT found)" 15 "PASS"
    elif [ -n "$PRODUCT_COUNT" ] && [ "$PRODUCT_COUNT" -gt 0 ]; then
        SCORE=$((SCORE + 5))
        printf "  ⚠️  %-4s %-48s %2d/%2d\n" "4.3" "Only $PRODUCT_COUNT product(s) — need 3" "5" "15"
    else
        check "4.3" "No products found" 15 "FAIL"
    fi
else
    check "4.3" "Cannot check products" 15 "FAIL"
fi

# ── SECTION 5: PERSONALIZATION (20 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 5: STORE PERSONALIZATION (20 pts)             │"
echo "└─────────────────────────────────────────────────────────┘"

SITE_TITLE=$(echo "$PAGE" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | head -1)
if [ -n "$SITE_TITLE" ] && ! echo "$SITE_TITLE" | grep -qi "^wordpress$"; then
    check "5.1" "Store name customized — $SITE_TITLE" 10 "PASS"
else
    check "5.1" "Store name is still default" 10 "FAIL"
fi

echo "$PAGE" | grep -qi "woocommerce\|product\|shop\|cart\|store" \
    && check "5.2" "Store page has shop content" 10 "PASS" \
    || check "5.2" "No shop content on front page" 10 "FAIL"

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
