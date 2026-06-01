import json
import csv
import boto3
import io

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Get bucket and file info from S3 event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    print(f"Processing file: {key} from bucket: {bucket}")

    # Read the CSV file from S3
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response['Body'].read().decode('utf-8')

    # Parse CSV
    reader = csv.DictReader(io.StringIO(content))

    total_grade = 0
    passed_count = 0
    failed_count = 0
    students = []

    for row in reader:
        # BUG #2: Wrong column name - CSV has 'grade' but code uses 'score'
        grade = float(row['score'])

        total_grade += grade

        if grade >= 75:
            passed_count += 1
        else:
            failed_count += 1

        students.append({
            'name': row['name'],
            'grade': grade
        })

    class_average = total_grade / len(students) if students else 0

    results = {
        'class_average': class_average,
        'passed_count': passed_count,
        'failed_count': failed_count,
        'students': students
    }

    # BUG #3: Wrong output path - website expects 'data/grades.json' but code writes 'data/results.json'
    output_key = 'data/results.json'

    s3.put_object(
        Bucket=bucket,
        Key=output_key,
        Body=json.dumps(results, indent=2),
        ContentType='application/json'
    )

    print(f"Results written to {output_key}")

    return {
        'statusCode': 200,
        'body': json.dumps('Grades processing complete!')
    }
