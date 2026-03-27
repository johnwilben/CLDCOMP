#!/bin/bash
echo "══════════════════════════════════════"
echo "  Security Group Checker"
echo "══════════════════════════════════════"
echo ""
read -p "Enter your Instance ID: " ID

if [ -z "$ID" ]; then
  echo "❌ No Instance ID entered."
  exit 1
fi

INFO=$(aws ec2 describe-instances --instance-ids "$ID" \
  --query "Reservations[].Instances[].[State.Name,PublicIpAddress,SecurityGroups[].GroupId]" \
  --output json 2>&1)

if echo "$INFO" | grep -q "InvalidInstanceID"; then
  echo "❌ Instance ID not found: $ID"
  exit 1
fi

STATE=$(echo "$INFO" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d[0][0][0])" 2>/dev/null)
IP=$(echo "$INFO" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d[0][0][1] or 'None')" 2>/dev/null)
SG=$(echo "$INFO" | python3 -c "import sys,json;d=json.load(sys.stdin);print(' '.join(d[0][0][2]))" 2>/dev/null)

echo ""
echo "Instance:  $ID"
echo "State:     $STATE"
echo "Public IP: $IP"
echo "SG:        $SG"
echo ""

if [ "$STATE" = "running" ]; then
  echo "✅ Instance is running"
else
  echo "❌ Instance is NOT running ($STATE)"
fi

HAS_SSH=false
HAS_HTTP=false

for sg in $SG; do
  RULES=$(aws ec2 describe-security-groups --group-ids "$sg" \
    --query "SecurityGroups[].IpPermissions[].[IpProtocol,FromPort,ToPort,IpRanges[].CidrIp,Ipv6Ranges[].CidrIpv6]" \
    --output json 2>/dev/null)

  if echo "$RULES" | grep -q '"FromPort": 22\|"FromPort":22'; then
    HAS_SSH=true
  fi
  if echo "$RULES" | grep -q '"FromPort": 80\|"FromPort":80'; then
    HAS_HTTP=true
  fi
  if echo "$RULES" | grep -q '"IpProtocol": "-1"'; then
    HAS_SSH=true
    HAS_HTTP=true
  fi
done

if $HAS_SSH; then
  echo "✅ Port 22 (SSH) is open"
else
  echo "❌ Port 22 (SSH) is NOT open"
fi

if $HAS_HTTP; then
  echo "✅ Port 80 (HTTP) is open"
else
  echo "❌ Port 80 (HTTP) is NOT open"
fi

echo ""
echo "══════════════════════════════════════"
