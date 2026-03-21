#!/bin/bash
# ══════════════════════════════════════════════════════════════
#  LAMP Stack Checker (Troubleshooting Activity)
#  curl -sL https://raw.githubusercontent.com/johnwilben/CLDCOMP/main/lamp-checker.sh | sudo bash
# ══════════════════════════════════════════════════════════════

SCORE=0
MAX=100

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --max-time 3 2>/dev/null)
PUB_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" --max-time 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'N/A')
INST_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" --max-time 3 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'N/A')
MAC=$(ip link show 2>/dev/null | grep ether | head -1 | awk '{print $2}')

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  LAMP Stack Checker"
echo "══════════════════════════════════════════════════════════"
echo ""
echo "  ┌───────────────────────────────────────────────────┐"
echo "  │  STUDENT FINGERPRINT (Do NOT alter this section)  │"
echo "  ├───────────────────────────────────────────────────┤"
echo "  │  Instance ID : $INST_ID"
echo "  │  Public IP   : $PUB_IP"
echo "  │  MAC Address : $MAC"
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

# ── SECTION 1: SERVICES (35 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 1: SERVICES (35 pts)                          │"
echo "└─────────────────────────────────────────────────────────┘"

[ "$(systemctl is-active apache2)" == "active" ] \
    && check "1.1" "Apache is running" 15 "PASS" \
    || check "1.1" "Apache is not running" 15 "FAIL"

[ "$(systemctl is-active mysql)" == "active" ] \
    && check "1.2" "MySQL is running" 15 "PASS" \
    || check "1.2" "MySQL is not running" 15 "FAIL"

A_EN=$(systemctl is-enabled apache2 2>/dev/null)
M_EN=$(systemctl is-enabled mysql 2>/dev/null)
[ "$A_EN" == "enabled" ] && [ "$M_EN" == "enabled" ] \
    && check "1.3" "Services enabled on boot" 5 "PASS" \
    || check "1.3" "Services on boot — apache2=$A_EN mysql=$M_EN" 5 "FAIL"

# ── SECTION 2: PHP MODULES (40 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 2: PHP MODULES (40 pts)                       │"
echo "└─────────────────────────────────────────────────────────┘"

dpkg -l 2>/dev/null | grep -q "libapache2-mod-php8.3" \
    && check "2.1" "libapache2-mod-php8.3 installed" 20 "PASS" \
    || check "2.1" "libapache2-mod-php8.3 missing" 20 "FAIL"

php -m 2>/dev/null | grep -qi "mysqli" \
    && check "2.2" "php8.3-mysql installed" 20 "PASS" \
    || check "2.2" "php8.3-mysql missing" 20 "FAIL"

# ── SECTION 3: APACHE MODULES (10 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 3: APACHE MODULES (10 pts)                    │"
echo "└─────────────────────────────────────────────────────────┘"

apache2ctl -M 2>/dev/null | grep -q rewrite \
    && check "3.1" "mod_rewrite enabled" 10 "PASS" \
    || check "3.1" "mod_rewrite not enabled" 10 "FAIL"

# ── SECTION 4: FUNCTIONALITY (15 pts) ──
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  SECTION 4: FUNCTIONALITY (15 pts)                     │"
echo "└─────────────────────────────────────────────────────────┘"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost/" 2>/dev/null)
[ "$HTTP_CODE" != "000" ] && [ "$HTTP_CODE" != "500" ] \
    && check "4.1" "HTTP responding — Status $HTTP_CODE" 8 "PASS" \
    || check "4.1" "HTTP not responding — Status $HTTP_CODE" 8 "FAIL"

PAGE=$(curl -s --max-time 5 "http://localhost/" 2>/dev/null)
if echo "$PAGE" | grep -q "<?php"; then
    check "4.2" "PHP processing (raw code detected!)" 7 "FAIL"
elif [ "$HTTP_CODE" != "000" ]; then
    check "4.2" "PHP processing correctly" 7 "PASS"
else
    check "4.2" "Cannot test PHP processing" 7 "FAIL"
fi

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
