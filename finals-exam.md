# Interim Lab Exam: Serverless CSV Dashboard

## Cloud Computing - Practical Exam

### Learning Outcomes

| # | Learning Outcome | Bloom's Level |
|---|---|---|
| 1 | Identify the components of a serverless application (S3, Lambda, IAM) | Remember |
| 2 | Explain how S3 event notifications trigger Lambda functions | Understand |
| 3 | Create and configure S3 buckets with static website hosting | Apply |
| 4 | Deploy a Lambda function and configure S3 triggers | Apply |
| 5 | Diagnose Lambda errors using CloudWatch Logs | Analyze |
| 6 | Fix code and permission issues to complete a working serverless pipeline | Evaluate |
| 7 | Apply the principle of least privilege when configuring IAM roles | Create |

### Exam Details

| Key | Value |
|-----|-------|
| Duration | 1 hour and 30 minutes |
| Type | Practical / Hands-On |
| Platform | AWS (S3 + Lambda) |
| Region | ap-southeast-1 (Singapore) |
| Collaboration | Individual work only |

---

## Scenario

You are building a **Serverless Sales Dashboard**. When a CSV file is uploaded to S3, a Lambda function processes it and generates a JSON report. A static website on S3 displays the results.

'''
Upload sales.csv to S3 "uploads/"
        |
        v
S3 triggers Lambda
        |
        v
Lambda reads CSV, calculates totals, writes results.json to "data/"
        |
        v
Static website displays dashboard from results.json
'''

**The Lambda code provided has 3 bugs.** Deploy the system, find the bugs using CloudWatch Logs, and fix them.

---

## Instructions

### Step 1: Create S3 Bucket

Create a bucket with the following:
- Name: 'cldcomp-interim-<yourlastname>' (e.g., 'cldcomp-interim-santos')
- Region: ap-southeast-1
- Public access: allowed (unblock)
- Static website hosting: enabled (index document = 'index.html')

### Step 2: Set Bucket Policy

Add a bucket policy that allows public read access to all objects in your bucket.

Go to your bucket -> Permissions -> Bucket policy -> Edit. Paste this (replace '<yourlastname>'):

'''json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::cldcomp-interim-<yourlastname>/*"
    }
  ]
}
'''

### Step 3: Upload Website Files

1. Create folders: 'uploads/' and 'data/'
2. Download 'index.html' from: 'https://raw.githubusercontent.com/johnwilben/CLDCOMP/main/index.html'
3. Replace '[YOUR FULL NAME HERE]' with your full name
4. Upload 'index.html' to the root of your bucket
5. Verify your website loads (should show "Loading data...")

### Step 4: Create Lambda Function

Create a Lambda function with:
- Name: 'cldcomp-interim-<yourlastname>-processor'
- Runtime: Python 3.12
- Architecture: x86_64
- Use the default execution role (auto-created)

Replace the default code with the code from:
'https://raw.githubusercontent.com/johnwilben/CLDCOMP/main/lambda_function.py'

Deploy the function.

### Step 5: Configure Lambda IAM Role

Your Lambda function needs permission to access S3. Add it now:

1. In your Lambda function, go to **Configuration** tab -> **Permissions**
2. Click the **Role name** link (opens IAM in a new tab)
3. Click **Add permissions** -> **Create inline policy**
4. Click the **JSON** tab
5. Paste this (replace '<yourlastname>'):

'''json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::cldcomp-interim-<yourlastname>/uploads/*"
    }
  ]
}
'''

6. Click **Next**
7. Policy name: 's3-access-policy'
8. Click **Create policy**

> NOTE: This policy only allows reading from S3. This is intentional — you will fix this during debugging.

### Step 6: Add S3 Trigger

Add an S3 trigger to your Lambda function:
- Bucket: your bucket
- Event type: All object create events
- Prefix: 'uploads/'
- Suffix: '.csv'

### Step 7: Test

1. Download 'sales.csv' from: 'https://raw.githubusercontent.com/johnwilben/CLDCOMP/main/sales.csv'
2. Upload it to your bucket's 'uploads/' folder
3. Wait 10-15 seconds
4. Check your website — does the dashboard show data?

If not, proceed to Step 8.

### Step 8: Debug

Your Lambda has **3 bugs**. Use **CloudWatch Logs** to find and fix them.

Find your logs at: CloudWatch -> Log groups -> '/aws/lambda/cldcomp-interim-<yourlastname>-processor'

**Hints:**
- Bug 1: Look for "AccessDenied." Lambda can read but can it write? Fix the IAM policy — do NOT use S3FullAccess.
- Bug 2: Look for "KeyError." The code references a column name that doesn't match the CSV. Compare them.
- Bug 3: No error in logs but website shows nothing. The code writes a file with a slightly different name than what the website expects.

After each fix:
- Code changes: click **Deploy**, then re-upload 'sales.csv'
- Permission changes: just re-upload 'sales.csv'

### Step 9: Verify

When all bugs are fixed:
- 'data/results.json' exists in your bucket
- Your website displays sales totals and a product table

### Step 10: Run Checker 

Command 1 (download): 

  curl -sL -H "Accept: application/vnd.github.v3.raw" "https://api.github.com/repos/johnwilben/CLDCOMP/contents/interim-checker.sh" -o interim-checker.sh 

Command 2 (run): 

  bash interim-checker.sh  

  Instructions for students: 
  1. Switch console region to US East (N. Virginia) 
  2. Open CloudShell 
  3. Paste Command 1, press Enter 
  4. Paste Command 2, press Enter 
  5. Type your last name when prompted 
  6. Screenshot the result 

### Step 11: Submit 

- Screenshot of your dashboard website (showing your name + data) 
- Screenshot of the checker output 

  If no checker available, students submit these screenshots:  

  1. S3 Bucket — showing bucket name, uploads/, data/results.json visible 
  2. Static Website — browser showing dashboard with their name + sales data 
  3. Lambda Function — showing function name, trigger configured (S3) 
  4. IAM Policy — showing the inline policy JSON (proves no S3FullAccess) 
  5. CloudWatch Logs — showing successful Lambda execution (no errors) 

---

## Grading Criteria (100 pts)

### Section 1: S3 Bucket Setup (15 pts)

| Check | Points | Pass | Fail |
|-------|--------|------|------|
| Bucket exists | 5 | 'cldcomp-interim-<lastname>' found | Not found = 0 |
| Naming correct | 5 | Follows 'cldcomp-interim-' prefix | Wrong name = 0 |
| Website hosting enabled | 5 | Static hosting is on | Not enabled = 0 |

### Section 2: Static Website (15 pts)

| Check | Points | Pass | Fail |
|-------|--------|------|------|
| index.html uploaded | 5 | File exists in bucket root | Not found = 0 |
| Website accessible | 5 | S3 website URL returns HTTP 200 | Not accessible = 0 |
| Student name displayed | 5 | Your last name appears on page | Not found = 0 |

### Section 3: Lambda Function (15 pts)

| Check | Points | Pass | Fail |
|-------|--------|------|------|
| Function exists | 5 | 'cldcomp-interim-<lastname>-processor' found | Not found = 0 |
| Python runtime | 5 | Runtime is python3.x | Wrong runtime = 0 |
| Correct handler | 5 | 'lambda_function.lambda_handler' | Wrong handler = 0 |

### Section 4: S3 Trigger (10 pts)

| Check | Points | Pass | Fail |
|-------|--------|------|------|
| Trigger configured | 5 | Lambda has S3 trigger on your bucket | No trigger = 0 |
| Correct prefix | 5 | Trigger filters on 'uploads/' | Wrong prefix = 0 |

### Section 5: Debugging - Lambda Works (20 pts)

| Check | Points | Pass | Fail |
|-------|--------|------|------|
| results.json exists | 10 | 'data/results.json' found in bucket | Not found = 0 |
| Correct data structure | 10 | JSON has 'total_sales', 'total_items', 'records' | Missing fields = 0 |

### Section 6: Dashboard Functional (10 pts)

| Check | Points | Pass | Fail |
|-------|--------|------|------|
| results.json publicly accessible | 5 | Fetchable via website URL | Not accessible = 0 |
| Dashboard references data | 5 | index.html loads results.json | Not referenced = 0 |

### Section 7: IAM Security (15 pts)

| Check | Points | Pass | Fail |
|-------|--------|------|------|
| Scoped permissions | 15 | Role uses s3:GetObject + s3:PutObject on your bucket only | 0 if S3FullAccess or AdministratorAccess attached |

> WARNING: Using AmazonS3FullAccess or AdministratorAccess = automatic 0/15 for this section.

---

## Reminders

- You have **1 hour and 30 minutes**.
- This is **individual work**. Do not share answers.
- **CloudWatch Logs** are your best friend for debugging.
- Do NOT use S3FullAccess — use scoped permissions.
- After fixing code, always click **Deploy** before re-testing.
- Re-upload 'sales.csv' after each fix to trigger Lambda again.
- Suggested time allocation:
  - S3 setup + website: ~20 minutes
  - Lambda + trigger: ~20 minutes
  - Debugging: ~30 minutes
  - Verify + checker: ~20 minutes

Good luck!
