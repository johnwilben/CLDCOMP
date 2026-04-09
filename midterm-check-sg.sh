#!/bin/bash
# Midterm SG Checker — Run from CloudShell
GSHEET="https://script.google.com/macros/s/AKfycbxZk6OvY_lUv65F-yzqcST7Udp1uSpRPDmeGCn2fzjvtIsY3V-7z85ED0I4uC_Rp0UIqA/exec"

echo "============================================"
echo "  🔒 MIDTERM SECURITY GROUP CHECKER"
echo "============================================"
echo ""

read -p "Enter your EC2 Instance ID (e.g., i-0abc123): " EC2_ID
read -p "Enter your RDS Instance Identifier (e.g., midterm-db-juan): " RDS_ID

echo ""
echo "Checking..."
SCORE=0

# Get EC2 SG
EC2_SGS=$(aws ec2 describe-instances --instance-ids "$EC2_ID" --query "Reservations[0].Instances[0].SecurityGroups[*].GroupId" --output text 2>/dev/null)
if [ -z "$EC2_SGS" ]; then
    echo "❌ Could not find EC2 instance $EC2_ID"
    exit 1
fi

echo ""
echo "📋 EC2 Security Group(s): $EC2_SGS"

# Check EC2 SG rules
for SG in $EC2_SGS; do
    echo ""
    echo "--- EC2 SG: $SG ---"
    
    # SSH = My IP (not 0.0.0.0/0)
    echo -n "  SSH (22) restricted to My IP: "
    SSH_OPEN=$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$SG" --query "SecurityGroupRules[?FromPort==\`22\` && IpProtocol=='tcp' && CidrIpv4=='0.0.0.0/0']" --output text 2>/dev/null)
    if [ -z "$SSH_OPEN" ]; then
        SSH_EXISTS=$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$SG" --query "SecurityGroupRules[?FromPort==\`22\` && IpProtocol=='tcp']" --output text 2>/dev/null)
        if [ -n "$SSH_EXISTS" ]; then
            echo "✅ PASS — SSH restricted (+10)"
            SCORE=$((SCORE+10))
            P_SSH="PASS"
        else
            echo "⚠️ No SSH rule found"
            P_SSH="MISSING"
        fi
    else
        echo "❌ FAIL — SSH is open to 0.0.0.0/0 (should be My IP)"
        P_SSH="FAIL"
    fi
    
    # HTTP = Anywhere
    echo -n "  HTTP (80) open to Anywhere: "
    HTTP_OPEN=$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$SG" --query "SecurityGroupRules[?FromPort==\`80\` && IpProtocol=='tcp' && CidrIpv4=='0.0.0.0/0']" --output text 2>/dev/null)
    if [ -n "$HTTP_OPEN" ]; then
        echo "✅ PASS — HTTP open (+10)"
        SCORE=$((SCORE+10))
        P_HTTP="PASS"
    else
        echo "❌ FAIL — HTTP not open to 0.0.0.0/0"
        P_HTTP="FAIL"
    fi
done

# Check RDS SG
echo ""
RDS_SGS=$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query "DBInstances[0].VpcSecurityGroups[*].VpcSecurityGroupId" --output text 2>/dev/null)
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query "DBInstances[0].Endpoint.Address" --output text 2>/dev/null)

if [ -z "$RDS_SGS" ] || [ "$RDS_SGS" = "None" ]; then
    echo "❌ Could not find RDS instance $RDS_ID"
    P_RDS="FAIL"
else
    echo "📋 RDS Security Group(s): $RDS_SGS"
    echo "📋 RDS Endpoint: $RDS_ENDPOINT"
    
    echo -n "  MySQL (3306) from EC2 SG: "
    for RSG in $RDS_SGS; do
        MYSQL_FROM_SG=$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$RSG" --query "SecurityGroupRules[?FromPort==\`3306\` && IpProtocol=='tcp' && ReferencedGroupInfo.GroupId!=\`\`]" --output text 2>/dev/null)
        MYSQL_FROM_CIDR=$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$RSG" --query "SecurityGroupRules[?FromPort==\`3306\` && IpProtocol=='tcp']" --output text 2>/dev/null)
    done
    
    if [ -n "$MYSQL_FROM_SG" ]; then
        echo "✅ PASS — MySQL allowed from SG (+10)"
        SCORE=$((SCORE+10))
        P_RDS="PASS"
    elif [ -n "$MYSQL_FROM_CIDR" ]; then
        echo "⚠️ PARTIAL — MySQL open but not via SG reference (+5)"
        SCORE=$((SCORE+5))
        P_RDS="PARTIAL"
    else
        echo "❌ FAIL — No MySQL rule found"
        P_RDS="FAIL"
    fi
fi

echo ""
echo "============================================"
echo "  📊 SG SCORE: $SCORE / 30"
echo "============================================"
echo "  SSH restricted: $P_SSH"
echo "  HTTP open: $P_HTTP"
echo "  RDS from EC2 SG: $P_RDS"
echo "============================================"
echo ""

# Update Google Sheet with SG results
read -p "Type 'SUBMIT' to upload SG results: " CONFIRM

if [ "$CONFIRM" = "SUBMIT" ]; then
    PAYLOAD=$(cat <<EOF
{
  "studentName": "SG_UPDATE",
  "instanceId": "$EC2_ID",
  "rdsEndpoint": "$RDS_ENDPOINT",
  "set": "SG",
  "score": "$SCORE",
  "p1": "$P_SSH",
  "p2": "$P_HTTP",
  "p3": "$P_RDS",
  "p4": "",
  "p5": "",
  "appInstalled": "",
  "sgCheck": "$SCORE/30",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "privateIp": "",
  "accountId": ""
}
EOF
)
    curl -s -L -X POST "$GSHEET" -H "Content-Type: application/json" -d "$PAYLOAD" >/dev/null 2>&1
    echo "✅ SG results submitted!"
else
    echo "❌ Submission cancelled."
fi
