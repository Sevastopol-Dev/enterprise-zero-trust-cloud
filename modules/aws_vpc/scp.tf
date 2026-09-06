resource "aws_organizations_policy" "guardrail_scp" {
  count = var.is_localstack ? 0 : 1
  
  name        = "pgh-banking-infrastructure-scp"
  description = "Denies disabling VPC Flow Logs or KMS key rotation"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyDisablingVPCFlowLogs"
        Effect   = "Deny"
        Action   = ["ec2:DeleteFlowLogs", "ec2:StopFlowLogs"]
        Resource = "*"
      },
      {
        Sid      = "DenyDisablingKMSKeyRotation"
        Effect   = "Deny"
        Action   = ["kms:DisableKey", "kms:DisableKeyRotation", "kms:ScheduleKeyDeletion"]
        Resource = "*"
      }
    ]
  })
}
