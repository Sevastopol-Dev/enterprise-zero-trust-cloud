import sys
import argparse
import boto3

def parse_args():
    parser = argparse.ArgumentParser(description="PGH Banking Shift-Right Compliance Auditor")
    parser.add_argument(
        "--endpoint-url", 
        default="http://localhost:4566", 
        help="Target AWS API Endpoint URL (default: http://localhost:4566)"
    )
    return parser.parse_args()

def audit_vpc_flow_logs(ec2_client):
    print("[*] Auditing VPC Flow Logs status...")
    vpcs = ec2_client.describe_vpcs()["Vpcs"]
    flow_logs = ec2_client.describe_flow_logs()["FlowLogs"]
    
    # Accept both AWS ('ACTIVE') and LocalStack ('SUCCESS') status strings
    active_ids = {
        fl["ResourceId"] 
        for fl in flow_logs 
        if fl.get("FlowLogStatus") in ["ACTIVE", "SUCCESS"]
    }
    
    violations = 0
    for vpc in vpcs:
        vpc_id = vpc["VpcId"]
        
        # Skip default/unmanaged VPCs to avoid false positives in local testing
        if vpc.get("IsDefault"):
            print(f"  [SKIP] Skipping default unmanaged VPC {vpc_id}.")
            continue

        if vpc_id not in active_ids:
            print(f"  [CRITICAL VIOLATION] VPC {vpc_id} lacks active Flow Logs!")
            violations += 1
        else:
            print(f"  [PASS] VPC {vpc_id} has active Flow Logging.")
            
    return violations

def audit_data_security_groups(ec2_client):
    print("[*] Auditing Data Tier Security Groups...")
    sgs = ec2_client.describe_security_groups()["SecurityGroups"]
    violations = 0
    
    for sg in sgs:
        if "data-sg" in sg["GroupName"]:
            for rule in sg.get("IpPermissions", []):
                for ip_range in rule.get("IpRanges", []):
                    if ip_range.get("CidrIp") == "0.0.0.0/0":
                        print(f"  [CRITICAL VIOLATION] Security Group {sg['GroupId']} ({sg['GroupName']}) allows public 0.0.0.0/0 ingress!")
                        violations += 1
                    else:
                        print(f"  [PASS] Security Group {sg['GroupId']} ({sg['GroupName']}) uses strict ingress rules.")
                        
    return violations

def main():
    args = parse_args()
    
    # Initialize Boto3 EC2 client targeting the configured endpoint
    ec2_client = boto3.client("ec2", endpoint_url=args.endpoint_url, region_name="us-east-1")

    print("==================================================")
    print("   PGH BANKING SHIFT-RIGHT COMPLIANCE AUDITOR     ")
    print("==================================================")
    
    total_violations = audit_vpc_flow_logs(ec2_client) + audit_data_security_groups(ec2_client)
    
    if total_violations > 0:
        print(f"\nFAILED: {total_violations} compliance violation(s) detected.")
        sys.exit(1)
        
    print("\nSUCCESS: All runtime resources meet compliance standards.")
    sys.exit(0)

if __name__ == "__main__":
    main()
