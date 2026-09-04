import boto3

def setup_backend():
    endpoint = "http://localhost:4566"
    region = "us-east-1"
    
    s3 = boto3.client("s3", endpoint_url=endpoint, region_name=region)
    dynamodb = boto3.client("dynamodb", endpoint_url=endpoint, region_name=region)
    
    bucket_name = "pgh-banking-tfstate-dev"
    table_name = "pgh-banking-tflocks-dev"

    # 1. Create S3 State Bucket
    print(f"[*] Creating S3 backend bucket: {bucket_name}")
    try:
        s3.create_bucket(Bucket=bucket_name)
        s3.put_bucket_versioning(
            Bucket=bucket_name,
            VersioningConfiguration={"Status": "Enabled"}
        )
        print(f"[PASS] Bucket '{bucket_name}' ready with versioning.")
    except Exception as e:
        print(f"[!] S3 Setup Warning: {e}")

    # 2. Create DynamoDB Lock Table
    print(f"[*] Creating DynamoDB lock table: {table_name}")
    try:
        dynamodb.create_table(
            TableName=table_name,
            KeySchema=[{"AttributeName": "LockID", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "LockID", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST"
        )
        print(f"[PASS] DynamoDB table '{table_name}' ready for state locking.")
    except Exception as e:
        print(f"[!] DynamoDB Setup Warning: {e}")

if __name__ == "__main__":
    setup_backend()
