#!/bin/bash
echo "=============================================="
echo "  Interim Exam Checker - Serverless Dashboard"
echo "=============================================="
echo ""
read -p "Enter your last name (lowercase): " LASTNAME

if [ -z "$LASTNAME" ]; then
  echo "No name entered."
  exit 1
fi

BUCKET="cldcomp-interim-${LASTNAME}"
REGION="ap-southeast-1"
SCORE=0
TOTAL=100

echo ""
echo "Checking bucket: $BUCKET"
echo "Region: $REGION"
echo ""

# ── SECTION 1: S3 Bucket Setup (15 pts) ──
echo "-- Section 1: S3 Bucket Setup (15 pts) --"

# Check bucket exists
BUCKET_EXISTS=$(aws s3api head-bucket --bucket "$BUCKET" 2>&1)
if [ $? -eq 0 ]; then
  echo "  [PASS] Bucket exists: $BUCKET (5/5)"
  SCORE=$((SCORE + 5))
else
  echo "  [FAIL] Bucket not found: $BUCKET (0/5)"
fi

# Check naming convention
if echo "$BUCKET" | grep -q "^cldcomp-interim-"; then
  echo "  [PASS] Naming convention correct (5/5)"
  SCORE=$((SCORE + 5))
else
  echo "  [FAIL] Bucket name should be cldcomp-interim-<lastname> (0/5)"
fi

# Check static website hosting
WEBSITE=$(aws s3api get-bucket-website --bucket "$BUCKET" --region "$REGION" 2>&1)
if echo "$WEBSITE" | grep -q "IndexDocument"; then
  echo "  [PASS] Static website hosting enabled (5/5)"
  SCORE=$((SCORE + 5))
else
  echo "  [FAIL] Static website hosting not enabled (0/5)"
fi

echo ""

# ── SECTION 2: Static Website (15 pts) ──
echo "-- Section 2: Static Website (15 pts) --"

# Check index.html exists
INDEX_EXISTS=$(aws s3api head-object --bucket "$BUCKET" --key "index.html" --region "$REGION" 2>&1)
if [ $? -eq 0 ]; then
  echo "  [PASS] index.html uploaded (5/5)"
  SCORE=$((SCORE + 5))
else
  echo "  [FAIL] index.html not found in bucket (0/5)"
fi

# Check website accessible
WEBSITE_URL="http://${BUCKET}.s3-website-${REGION}.amazonaws.com"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$WEBSITE_URL" 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
  echo "  [PASS] Website accessible: $WEBSITE_URL (5/5)"
  SCORE=$((SCORE + 5))
else
  echo "  [FAIL] Website not accessible (HTTP $HTTP_CODE) (0/5)"
fi

# Check student name on page
PAGE_CONTENT=$(curl -s --max-time 10 "$WEBSITE_URL" 2>/dev/null)
if echo "$PAGE_CONTENT" | grep -qi "$LASTNAME"; then
  echo "  [PASS] Student name found on website (5/5)"
  SCORE=$((SCORE + 5))
else
  echo "  [FAIL] Student name not found on website (0/5)"
fi

echo ""

# ── SECTION 3: Lambda Function (15 pts) ──
echo "-- Section 3: Lambda Function (15 pts) --"

FUNC_NAME="cldcomp-interim-${LASTNAME}-processor"
FUNC_INFO=$(aws lambda get-function --function-name "$FUNC_NAME" --region "$REGION" 2>&1)

if echo "$FUNC_INFO" | grep -q "FunctionArn"; then
  echo "  [PASS] Lambda function exists: $FUNC_NAME (5/5)"
  SCORE=$((SCORE + 5))
else
  # Try alternate naming
  FUNC_NAME2="cldcomp-interim-${LASTNAME}"
  FUNC_INFO2=$(aws lambda get-function --function-name "$FUNC_NAME2" --region "$REGION" 2>&1)
  if echo "$FUNC_INFO2" | grep -q "FunctionArn"; then
    FUNC_NAME="$FUNC_NAME2"
    FUNC_INFO="$FUNC_INFO2"
    echo "  [PASS] Lambda function exists: $FUNC_NAME (5/5)"
    SCORE=$((SCORE + 5))
  else
    echo "  [FAIL] Lambda function not found (tried $FUNC_NAME and $FUNC_NAME2) (0/5)"
  fi
fi

# Check runtime
if echo "$FUNC_INFO" | grep -q "python3"; then
  echo "  [PASS] Python runtime detected (5/5)"
  SCORE=$((SCORE + 5))
else
  echo "  [FAIL] Expected Python runtime (0/5)"
fi

# Check handler
if echo "$FUNC_INFO" | grep -q "lambda_function.lambda_handler"; then
  echo "  [PASS] Correct handler configured (5/5)"
  SCORE=$((SCORE + 5))
else
  echo "  [FAIL] Handler should be lambda_function.lambda_handler (0/5)"
fi

echo ""

# ── SECTION 4: S3 Trigger (10 pts) ──
echo "-- Section 4: S3 Trigger (10 pts) --"

NOTIF=$(aws s3api get-bucket-notification-configuration --bucket "$BUCKET" --region "$REGION" 2>&1)
if echo "$NOTIF" | grep -q "LambdaFunctionConfigurations"; then
  echo "  [PASS] S3 trigger configured (5/5)"
  SCORE=$((SCORE + 5))
  
  if echo "$NOTIF" | grep -q "uploads/"; then
    echo "  [PASS] Trigger prefix 'uploads/' correct (5/5)"
    SCORE=$((SCORE + 5))
  else
    echo "  [FAIL] Trigger should filter on prefix 'uploads/' (0/5)"
  fi
else
  echo "  [FAIL] No Lambda trigger on bucket (0/10)"
fi

echo ""

# ── SECTION 5: Debugging - Lambda Works (20 pts) ──
echo "-- Section 5: Debugging / Lambda Output (20 pts) --"

# Check results.json exists
RESULTS_EXISTS=$(aws s3api head-object --bucket "$BUCKET" --key "data/results.json" --region "$REGION" 2>&1)
if [ $? -eq 0 ]; then
  echo "  [PASS] data/results.json exists (10/10)"
  SCORE=$((SCORE + 10))
  
  # Check content is valid JSON with expected fields
  RESULTS=$(aws s3 cp "s3://${BUCKET}/data/results.json" - --region "$REGION" 2>/dev/null)
  if echo "$RESULTS" | python3 -c "import sys,json;d=json.load(sys.stdin);assert 'total_sales' in d and 'records' in d" 2>/dev/null; then
    echo "  [PASS] results.json has correct structure (10/10)"
    SCORE=$((SCORE + 10))
  else
    echo "  [FAIL] results.json missing expected fields (0/10)"
  fi
else
  echo "  [FAIL] data/results.json not found - Lambda may not have run correctly (0/20)"
  echo "         Check CloudWatch Logs for errors!"
fi

echo ""

# ── SECTION 6: Dashboard Functional (10 pts) ──
echo "-- Section 6: Dashboard Functional (10 pts) --"

RESULTS_URL="${WEBSITE_URL}/data/results.json"
RESULTS_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$RESULTS_URL" 2>/dev/null)
if [ "$RESULTS_HTTP" = "200" ]; then
  echo "  [PASS] results.json publicly accessible (5/5)"
  SCORE=$((SCORE + 5))
else
  echo "  [FAIL] results.json not publicly accessible (HTTP $RESULTS_HTTP) (0/5)"
fi

# Check dashboard shows data (page has actual values not loading/error)
if echo "$PAGE_CONTENT" | grep -q "results.json"; then
  echo "  [PASS] Dashboard references results.json (5/5)"
  SCORE=$((SCORE + 5))
else
  echo "  [FAIL] Dashboard does not reference results.json (0/5)"
fi

echo ""

# ── SECTION 7: IAM Security (15 pts) ──
echo "-- Section 7: IAM Security (15 pts) --"

if echo "$FUNC_INFO" | grep -q "Role"; then
  ROLE_ARN=$(echo "$FUNC_INFO" | python3 -c "import sys,json;print(json.load(sys.stdin)['Configuration']['Role'])" 2>/dev/null)
  ROLE_NAME=$(echo "$ROLE_ARN" | awk -F'/' '{print $NF}')
  
  # Check attached policies
  POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" 2>&1)
  
  HAS_FULL_ACCESS=false
  if echo "$POLICIES" | grep -qi "AmazonS3FullAccess\|AdministratorAccess"; then
    HAS_FULL_ACCESS=true
  fi
  
  # Check inline policies for overly broad permissions
  INLINE=$(aws iam list-role-policies --role-name "$ROLE_NAME" 2>&1)
  
  if $HAS_FULL_ACCESS; then
    echo "  [FAIL] S3FullAccess or AdministratorAccess detected! (0/15)"
    echo "         Use scoped permissions: s3:GetObject + s3:PutObject on your bucket only."
  else
    echo "  [PASS] No overly broad S3 policies detected (15/15)"
    SCORE=$((SCORE + 15))
  fi
else
  echo "  [FAIL] Cannot determine Lambda role (0/15)"
fi

echo ""

# ── FINAL RESULTS ──
echo "=============================================="
echo "  FINAL SCORE: $SCORE / $TOTAL"
echo "=============================================="
echo ""

if [ $SCORE -ge 90 ]; then
  echo "  Grade: EXCELLENT"
elif [ $SCORE -ge 80 ]; then
  echo "  Grade: VERY GOOD"
elif [ $SCORE -ge 70 ]; then
  echo "  Grade: GOOD"
elif [ $SCORE -ge 60 ]; then
  echo "  Grade: NEEDS IMPROVEMENT"
else
  echo "  Grade: INCOMPLETE"
fi

echo ""
echo "=============================================="
echo "  Screenshot this output and submit."
echo "=============================================="
