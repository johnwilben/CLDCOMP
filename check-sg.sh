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

INFO=$(aws ec2 describe-instances --instance-ids "$ID" --output json 2>&1)

if echo "$INFO" | grep -q "InvalidInstanceID\|error"; then
  echo "❌ Instance ID not found: $ID"
  exit 1
fi

STATE=$(echo "$INFO" | jq -r '.Reservations[0].Instances[0].State.Name')
IP=$(echo "$INFO" | jq -r '.Reservations[0].Instances[0].PublicIpAddress // "None"')
SGS=$(echo "$INFO" | jq -r '.Reservations[0].Instances[0].SecurityGroups[].GroupId')

echo ""
echo "Instance:  $ID"
echo "State:     $STATE"
echo "Public IP: $IP"
echo "SG:        $SGS"
echo ""

if [ "$STATE" = "running" ]; then
  echo "✅ Instance is running"
else
  echo "❌ Instance is NOT running ($STATE)"
fi

HAS_SSH=false
HAS_HTTP=false

for sg in $SGS; do
  RULES=$(aws ec2 describe-security-groups --group-ids "$sg" --output json 2>/dev/null)

  # Check each rule
  PORTS=$(echo "$RULES" | jq -r '.SecurityGroups[].IpPermissions[] | "\(.IpProtocol) \(.FromPort)"')

  while read -r proto port; do
    [ "$proto" = "-1" ] && HAS_SSH=true && HAS_HTTP=true
    [ "$port" = "22" ] && HAS_SSH=true
    [ "$port" = "80" ] && HAS_HTTP=true
  done <<< "$PORTS"
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
