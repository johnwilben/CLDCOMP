#!/bin/bash
echo "══════════════════════════════════════"
echo "  Security Group Checker (20 pts)"
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
INAME=$(echo "$INFO" | jq -r '.Reservations[0].Instances[0].Tags[]? | select(.Key=="Name") | .Value // "No Name"')

echo ""
echo "Instance:  $ID"
echo "Name:      $INAME"
echo "State:     $STATE"
echo "Public IP: $IP"
echo "SG:        $SGS"
echo ""

if echo "$INAME" | grep -q "^CLDCOMP_interim_"; then
  echo "✅ Instance name follows format: $INAME"
else
  echo "⚠️  Instance name should be CLDCOMP_interim_<YourName> (found: $INAME)"
fi

SCORE=0

if [ "$STATE" = "running" ]; then
  echo "✅ Instance is running"
else
  echo "❌ Instance is NOT running ($STATE)"
fi

SSH_OPEN=false
SSH_MYIP=true
HTTP_OPEN=false
HTTP_ANYWHERE=false

for sg in $SGS; do
  RULES=$(aws ec2 describe-security-groups --group-ids "$sg" --output json 2>/dev/null)

  SSH_CIDRS=$(echo "$RULES" | jq -r '.SecurityGroups[].IpPermissions[] | select(.FromPort==22) | .IpRanges[].CidrIp')
  if [ -n "$SSH_CIDRS" ]; then
    SSH_OPEN=true
    for cidr in $SSH_CIDRS; do
      if [ "$cidr" = "0.0.0.0/0" ]; then
        SSH_MYIP=false
      fi
    done
  fi

  HTTP_CIDRS=$(echo "$RULES" | jq -r '.SecurityGroups[].IpPermissions[] | select(.FromPort==80) | .IpRanges[].CidrIp')
  if [ -n "$HTTP_CIDRS" ]; then
    HTTP_OPEN=true
    for cidr in $HTTP_CIDRS; do
      if [ "$cidr" = "0.0.0.0/0" ]; then
        HTTP_ANYWHERE=true
      fi
    done
  fi

  ALL=$(echo "$RULES" | jq -r '.SecurityGroups[].IpPermissions[] | select(.IpProtocol=="-1") | .IpRanges[].CidrIp')
  if [ -n "$ALL" ]; then
    SSH_OPEN=true
    HTTP_OPEN=true
    SSH_MYIP=false
    for cidr in $ALL; do
      if [ "$cidr" = "0.0.0.0/0" ]; then
        HTTP_ANYWHERE=true
      fi
    done
  fi
done

echo ""
echo "── SSH (Port 22) — 10 pts ──"
if $SSH_OPEN && $SSH_MYIP; then
  echo "✅ Port 22 is open (My IP only) — 10/10"
  SCORE=$((SCORE + 10))
elif $SSH_OPEN && ! $SSH_MYIP; then
  echo "⚠️  Port 22 is open but set to 0.0.0.0/0 — Should be My IP only! — 5/10"
  SCORE=$((SCORE + 5))
else
  echo "❌ Port 22 (SSH) is NOT open — 0/10"
fi

echo ""
echo "── HTTP (Port 80) — 10 pts ──"
if $HTTP_OPEN && $HTTP_ANYWHERE; then
  echo "✅ Port 80 is open (Anywhere 0.0.0.0/0) — 10/10"
  SCORE=$((SCORE + 10))
elif $HTTP_OPEN && ! $HTTP_ANYWHERE; then
  echo "⚠️  Port 80 is open but NOT set to Anywhere — Should be 0.0.0.0/0! — 5/10"
  SCORE=$((SCORE + 5))
else
  echo "❌ Port 80 (HTTP) is NOT open — 0/10"
fi

echo ""
echo "══════════════════════════════════════"
echo "  SECURITY GROUP SCORE: $SCORE / 20"
echo "══════════════════════════════════════"
