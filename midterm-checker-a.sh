#!/bin/bash
GSHEET="https://script.google.com/macros/s/AKfycbzmaSHZe8VphMV_Ogri449fQcyEiPOxlwpu0jbMILzw8ucU6ORUQ_numN4Ya2QqyvPQ5A/exec"
SET="A"
APP="WordPress"
SCORE=0

echo "============================================"
echo "  MIDTERM CHECKER — SET $SET ($APP)"
echo "============================================"
echo ""

# Fingerprint — handle IMDSv2 and missing tags gracefully
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
ACCOUNT_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document 2>/dev/null | grep -o '"accountId" : "[^"]*"' | cut -d'"' -f4)
STUDENT_NAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/Name 2>/dev/null)

# Clean up — if metadata returns HTML/XML, it failed
if echo "$INSTANCE_ID" | grep -q "<?xml"; then INSTANCE_ID="unknown"; fi
if echo "$STUDENT_NAME" | grep -q "<?xml\|404\|html"; then STUDENT_NAME="unknown"; fi
if [ -z "$INSTANCE_ID" ]; then INSTANCE_ID="unknown"; fi
if [ -z "$STUDENT_NAME" ]; then STUDENT_NAME="unknown"; fi
if [ -z "$ACCOUNT_ID" ]; then ACCOUNT_ID="unknown"; fi
if [ -z "$PRIVATE_IP" ]; then PRIVATE_IP="unknown"; fi
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# If name unknown, ask
if [ "$STUDENT_NAME" = "unknown" ]; then
    read -p "Could not detect your Name tag. Enter your full name: " STUDENT_NAME
fi

echo "Student: $STUDENT_NAME"
echo "Instance: $INSTANCE_ID"
echo "Time: $TIMESTAMP"
echo ""
echo "--- Troubleshooting ---"
echo -n "1. Apache running: "
if systemctl is-active apache2 >/dev/null 2>&1; then
    echo "PASS (+7)"; P1="PASS"; SCORE=$((SCORE+7))
else
    echo "FAIL"; P1="FAIL"
fi
echo -n "2. PHP-Apache module: "
if apache2ctl -M 2>/dev/null | grep -q php; then
    echo "PASS (+7)"; P2="PASS"; SCORE=$((SCORE+7))
else
    echo "FAIL"; P2="FAIL"
fi
echo -n "3. PHP-MySQL module: "
if php -m 2>/dev/null | grep -qi mysqli; then
    echo "PASS (+7)"; P3="PASS"; SCORE=$((SCORE+7))
else
    echo "FAIL"; P3="FAIL"
fi
echo ""
echo "--- EC2 + RDS ---"

# EC2 naming
echo -n "4. EC2 Name tag: "
if echo "$STUDENT_NAME" | grep -qi "CLDCOMP_midterm"; then
    echo "PASS — $STUDENT_NAME (+10)"; SCORE=$((SCORE+10))
else
    echo "WARNING — Name: $STUDENT_NAME (+5)"; SCORE=$((SCORE+5))
fi

# App + RDS
echo -n "5. WordPress + RDS connection: "
RDS_ENDPOINT="none"
APP_CHECK="FAIL"
if [ -f /var/www/html/wp-config.php ]; then
    DBHOST=$(grep "DB_HOST" /var/www/html/wp-config.php 2>/dev/null | grep -o "'[^']*'" | tail -1 | tr -d "'")
    RDS_ENDPOINT="$DBHOST"
    if echo "$DBHOST" | grep -q "rds.amazonaws.com"; then
        echo "PASS — Connected to RDS (+16)"; SCORE=$((SCORE+16)); APP_CHECK="PASS"
    else
        echo "PARTIAL — config exists but DB_HOST is not RDS (+8)"; SCORE=$((SCORE+8)); APP_CHECK="PARTIAL"
    fi
else
    echo "FAIL — config file not found"
fi

# Site loads
echo -n "6. Site loads: "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "PASS (HTTP $HTTP_CODE) (+8)"; SCORE=$((SCORE+8))
else
    echo "FAIL (HTTP $HTTP_CODE)"
fi

# Personalization
echo -n "7. Site personalized: "
SITE_TITLE=$(curl -s http://localhost/ 2>/dev/null | grep -o '<title>[^<]*</title>' | head -1)
if [ -n "$SITE_TITLE" ] && [ "$SITE_TITLE" != "<title></title>" ]; then
    echo "PASS — $SITE_TITLE (+8)"; SCORE=$((SCORE+8))
else
    echo "FAIL"
fi

# File ownership
echo -n "8. File ownership (www-data): "
OWNER=$(stat -c '%U' /var/www/html/index.php 2>/dev/null || echo "unknown")
if [ "$OWNER" = "www-data" ]; then
    echo "PASS (+5)"; SCORE=$((SCORE+5))
else
    echo "FAIL — Owner: $OWNER"
fi

echo ""
echo "============================================"
echo "  SCORE: $SCORE / 100"
echo "============================================"
if [ $SCORE -ge 90 ]; then GRADE="EXCELLENT"
elif [ $SCORE -ge 80 ]; then GRADE="VERY GOOD"
elif [ $SCORE -ge 70 ]; then GRADE="GOOD"
elif [ $SCORE -ge 60 ]; then GRADE="NEEDS IMPROVEMENT"
else GRADE="INCOMPLETE"; fi
echo "  Grade: $GRADE"
echo "============================================"
echo ""
echo "Ready to submit your results?"
echo "   Name: $STUDENT_NAME"
echo "   Score: $SCORE/100"
echo "   Instance: $INSTANCE_ID"
echo ""
read -p "Type SUBMIT to upload your score: " CONFIRM
if [ "$CONFIRM" = "SUBMIT" ]; then
    PAYLOAD="{\"studentName\":\"$STUDENT_NAME\",\"instanceId\":\"$INSTANCE_ID\",\"rdsEndpoint\":\"$RDS_ENDPOINT\",\"set\":\"$SET\",\"score\":\"$SCORE\",\"p1\":\"$P1\",\"p2\":\"$P2\",\"p3\":\"$P3\",\"appInstalled\":\"$APP_CHECK\",\"sgCheck\":\"pending\",\"timestamp\":\"$TIMESTAMP\",\"privateIp\":\"$PRIVATE_IP\",\"accountId\":\"$ACCOUNT_ID\"}"
    curl -s -L -X POST "$GSHEET" -H "Content-Type: application/json" -d "$PAYLOAD" >/dev/null 2>&1
    echo ""
    echo "Results submitted successfully!"
else
    echo ""
    echo "Submission cancelled. Run the checker again when ready."
fi
