# Finals Lab Exam — Set A: Inventory Tracker

## Cloud Computing - Practical Exam

---

## Learning Outcomes (Bloom's Taxonomy)

| Level | What You'll Demonstrate |
|-------|------------------------|
| **Remember** | Identify what S3, Lambda, and IAM do |
| **Understand** | Explain how static hosting, Lambda triggers, and IAM policies connect |
| **Apply** | Set up S3 buckets, Lambda functions, IAM roles, and event triggers |
| **Analyze** | Read CloudWatch Logs to trace and fix errors in Lambda |
| **Evaluate** | Choose the correct least-privilege IAM permissions |
| **Create** | Deliver a working serverless dashboard |

---

## The Scenario

A sari-sari store owner is tired of manually counting stock. Every week, they update a spreadsheet with their inventory — item names, quantities, and prices. They want a simple dashboard that shows at a glance: how much stock they have, which items are running low, and the total value of their inventory.

Your job is to build a serverless system that does this automatically. The store owner uploads their inventory CSV file, and within seconds, a live dashboard updates with all the numbers. No servers to manage. No IT team needed. Just upload and go.

---

## Your Files

| File | What it is |
|------|-----------|
| `index.html` | The dashboard website — shows inventory stats and a table of items |
| `inventory.csv` | The store's current inventory data (item, stock, price) |
| `lambda_function.py` | The processing code — reads the CSV and generates dashboard data |

---

## What the Dashboard Should Show (When Working)

- **Total Stock** — sum of all item quantities
- **Low Stock Items** — count of items with 10 or fewer units (these need restocking!)
- **Inventory Value** — total value of all stock (quantity x price)
- A table listing every item with its stock level, price, and a status indicator (LOW or OK)

---

## What You Need To Do

### 1. Create Your S3 Bucket (Apply)

Create a bucket named `finals-<your-student-id>` in ap-southeast-1. Enable static website hosting with `index.html` as the index document. Disable Block Public Access and write the following bucket policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::finals-<your-student-id>/*"
    }
  ]
}
```

Replace `<your-student-id>` with your actual student ID.

### 2. Create Your IAM Role (Evaluate)

Create an IAM role for Lambda. Attach the managed policy `AWSLambdaBasicExecutionRole` (for CloudWatch Logs). Then add the following inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::finals-<your-student-id>/*"
    }
  ]
}
```

> Note: This policy may not be complete. If Lambda encounters permission errors, check CloudWatch Logs and fix the policy accordingly. Do NOT use `S3FullAccess` or `AdministratorAccess`.

### 3. Create Your Lambda Function (Apply)

Create a function named `ProcessCSV-<your-student-id>` with Python 3.12 runtime. Upload the provided `lambda_function.py` and attach your IAM role.

### 4. Set Up the S3 Trigger (Apply)

Add an event notification on your bucket so Lambda runs when a `.csv` file is uploaded. Use suffix filter `.csv` to prevent infinite loops.

### 5. Upload Your Files (Apply)

- Edit `index.html` — replace `YOUR NAME HERE` with your full name
- Upload `index.html` to the root of your bucket
- Upload `inventory.csv` to the root of your bucket

### 6. Debug the Lambda Function (Analyze)

The Lambda code has **3 bugs**. Use CloudWatch Logs to find and fix them.

**Hints:**
- One bug causes the function to **time out** — CloudWatch shows "Task timed out after 3.00 seconds." Something in the code is making it take too long. Check the Lambda timeout setting AND the code.
- One bug causes a `KeyError` — the code looks for a column that doesn't exist in the CSV. Compare the CSV headers with what the code expects.
- One bug causes a `NoSuchBucket` error — the code is trying to write to a bucket that doesn't exist. Look at where the output is being saved.

Fix all 3, re-upload the CSV, and your dashboard will come alive.

---

## Deliverables (Screenshots)

| # | Screenshot | Bloom's Level |
|---|-----------|---------------|
| 1 | S3 bucket properties showing Static Website Hosting enabled | Apply |
| 2 | Bucket policy JSON | Evaluate |
| 3 | Block Public Access settings (all disabled) | Apply |
| 4 | IAM policy JSON attached to Lambda execution role | Evaluate |
| 5 | Lambda function showing corrected code (highlight the 3 fixes) | Analyze |
| 6 | S3 event notification configuration | Apply |
| 7 | Working dashboard in browser (with your name and data) | Create |
| 8 | Generated JSON file contents in S3 (data/ folder) | Create |

Compile into one PDF: `FINALS-<your-student-id>.pdf`

---

## Grading Rubric (100 pts)

| Section | Points | Criteria |
|---------|--------|----------|
| **S3 Bucket Setup** | 15 | Bucket exists with correct name, static website hosting enabled, Block Public Access disabled |
| **Bucket Policy** | 10 | Valid JSON policy allowing public `s3:GetObject` on the correct resource ARN |
| **IAM Role** | 15 | Scoped permissions only (`s3:GetObject`, `s3:PutObject` on specific bucket). Deduct all 15 if `S3FullAccess` or `AdministratorAccess` used |
| **Lambda Function** | 10 | Function exists, correct name, Python 3.12 runtime, correct handler |
| **S3 Trigger** | 10 | Event notification configured with `.csv` suffix filter pointing to Lambda |
| **Bug Fix 1** | 10 | Lambda timeout fixed (removed sleep or increased timeout to 10+ sec) |
| **Bug Fix 2** | 10 | Correct column name used (matches CSV headers) |
| **Bug Fix 3** | 10 | Correct output bucket (uses actual bucket name, not hardcoded placeholder) |
| **Working Dashboard** | 10 | Website loads with student name and correct data displayed |
| **Total** | **100** | |

---

## Reminders

- You have **2 hours**.
- **CloudWatch Logs** are your best friend for debugging.
- If dashboard shows "not available" — Lambda either didn't run or has errors.
- If Lambda shows "AccessDenied" — your IAM role is missing permissions.
- If website loads but no data — check the output filename.
- Do NOT use FullAccess or Admin policies.

Good luck!
