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
    
    total_sales = 0
    total_items = 0
    records = []
    
    for row in reader:
        # BUG #2: Wrong column name - CSV has 'amount' but code uses 'total'
        total_sales += float(row['total'])
        total_items += int(row['quantity'])
        records.append({
            'product': row['product'],
            'quantity': int(row['quantity']),
            'amount': float(row['total'])
        })
    
    # Build results
    results = {
        'total_sales': total_sales,
        'total_items': total_items,
        'record_count': len(records),
        'records': records
    }
    
    # BUG #3: Wrong output filename - website expects 'results.json' but code writes 'result.json'
    output_key = 'data/result.json'
    
    s3.put_object(
        Bucket=bucket,
        Key=output_key,
        Body=json.dumps(results, indent=2),
        ContentType='application/json'
    )
    
    print(f"Results written to {output_key}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete!')
    }
