import json
import csv
import boto3
import io
import time

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Get bucket and file info from S3 event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    print(f"Processing file: {key} from bucket: {bucket}")

    # Simulate processing time
    # BUG #1: This sleep causes the function to exceed the default 3-second timeout
    time.sleep(5)

    # Read the CSV file from S3
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response['Body'].read().decode('utf-8')

    # Parse CSV
    reader = csv.DictReader(io.StringIO(content))

    total_stock = 0
    total_value = 0
    low_stock_count = 0
    items = []

    for row in reader:
        stock = int(row['stock'])
        # BUG #2: Wrong column name - CSV has 'price' but code uses 'cost'
        price = float(row['cost'])

        total_stock += stock
        total_value += stock * price

        if stock <= 10:
            low_stock_count += 1

        items.append({
            'item': row['item'],
            'stock': stock,
            'price': price
        })

    results = {
        'total_stock': total_stock,
        'total_value': total_value,
        'low_stock_count': low_stock_count,
        'items': items
    }

    # BUG #3: Hardcoded wrong bucket name - should be the actual bucket from the event
    output_bucket = 'finals-CHANGE-ME'

    s3.put_object(
        Bucket=output_bucket,
        Key='data/inventory.json',
        Body=json.dumps(results, indent=2),
        ContentType='application/json'
    )

    print(f"Results written to {output_bucket}/data/inventory.json")

    return {
        'statusCode': 200,
        'body': json.dumps('Inventory processing complete!')
    }
