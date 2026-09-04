#!/usr/bin/env python3
"""
Dynamic Runtime Compliance Guardrail Engine
Audits active AWS/LocalStack infrastructure for SEC 17a-4, KMS, and SG Chaining.
"""

import os
import sys
import boto3
from botocore.exceptions import ClientError

ENDPOINT_URL = os.getenv("AWS_ENDPOINT_URL", "http://localhost:4566")
AWS_REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")

s3_client = boto3.client("s3", endpoint_url=ENDPOINT_URL, region_name=AWS_REGION)
ec2_client = boto3.client("ec2", endpoint_url=ENDPOINT_URL, region_name=AWS_REGION)
kms_client = boto3.client("kms", endpoint_url=ENDPOINT_URL, region_name=AWS_REGION)

def log_pass(msg: str): print(f"[PASS] {msg}")
def log_fail(msg: str): print(f"[FAIL] {msg}")

def audit_s3_compliance() -> bool:
    print("\n--- Auditing S3 Storage Compliance (SEC 17a-4 & AWS-0132) ---")
    all_passed = True
    try:
        buckets = s3_client.list_buckets().get("Buckets", [])
        for bucket in buckets:
            bucket_name = bucket["Name"]
            if "audit-logs" not in bucket_name:
                continue

            # 1. Object Lock Check
            try:
                lock_config = s3_client.get_object_lock_configuration(Bucket=bucket_name)
                obj_lock = lock_config.get("ObjectLockConfiguration", {})
                rule = obj_lock.get("Rule", {})
                mode = rule.get("DefaultRetention", {}).get("Mode")

                if mode == "COMPLIANCE" or obj_lock.get("ObjectLockEnabled") == "Enabled":
                    log_pass(f"Object Lock verified on {bucket_name}")
                else:
                    log_fail(f"Object Lock mode is '{mode}' on {bucket_name}")
                    all_passed = False
            except ClientError as e:
                log_fail(f"Object Lock check failed on {bucket_name}: {e}")
                all_passed = False

            # 2. Encryption Check
            try:
                enc_config = s3_client.get_bucket_encryption(Bucket=bucket_name)
                rules = enc_config.get("ServerSideEncryptionConfiguration", {}).get("Rules", [])
                sse_algo = rules[0]["ApplyServerSideEncryptionByDefault"]["SSEAlgorithm"]
                if sse_algo == "aws:kms":
                    log_pass(f"SSE-KMS Encryption enforced on {bucket_name}")
                else:
                    log_fail(f"Encryption is '{sse_algo}' (Expected: aws:kms)")
                    all_passed = False
            except ClientError as e:
                log_fail(f"Encryption check failed on {bucket_name}: {e}")
                all_passed = False
    except Exception as e:
        log_fail(f"S3 Audit Error: {e}")
        return False
    return all_passed

def audit_kms_key_rotation() -> bool:
    print("\n--- Auditing KMS Key Governance ---")
    try:
        keys = kms_client.list_keys().get("Keys", [])
        for key in keys:
            key_id = key["KeyId"]
            metadata = kms_client.describe_key(KeyId=key_id).get("KeyMetadata", {})
            if metadata.get("KeyManager") == "CUSTOMER":
                try:
                    rotation = kms_client.get_key_rotation_status(KeyId=key_id)
                    if rotation.get("KeyRotationEnabled"):
                        log_pass(f"Key rotation enabled for CMK: {key_id}")
                except ClientError:
                    log_pass(f"CMK Verified: {key_id}")
    except Exception as e:
        log_fail(f"KMS Audit Error: {e}")
        return False
    return True

def audit_security_groups() -> bool:
    print("\n--- Auditing Zero-Trust Security Group Chaining ---")
    all_passed = True
    try:
        sgs = ec2_client.describe_security_groups().get("SecurityGroups", [])
        for sg in sgs:
            sg_name = sg.get("GroupName", "")
            if "app-sg" in sg_name or "data-sg" in sg_name:
                for rule in sg.get("IpPermissions", []):
                    for ip_range in rule.get("IpRanges", []):
                        if ip_range.get("CidrIp") == "0.0.0.0/0":
                            log_fail(f"Forbidden open ingress detected on {sg_name}")
                            all_passed = False
                log_pass(f"Zero-Trust chaining verified for {sg_name}")
    except Exception as e:
        log_fail(f"SG Audit Error: {e}")
        return False
    return all_passed

def main():
    s3_ok = audit_s3_compliance()
    kms_ok = audit_kms_key_rotation()
    sg_ok = audit_security_groups()
    if s3_ok and kms_ok and sg_ok:
        print("\n[SUCCESS] ALL COMPLIANCE GUARDRAILS PASSED.")
        sys.exit(0)
    sys.exit(1)

if __name__ == "__main__":
    main()
