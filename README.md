---



---

## 🏛️ Architecture Overview

The system provisions a secure 3-Tier VPC model with strict network isolation, customer-managed encryption, and immutable audit logs:


```
              +-----------------------------------+
              |      Internet Gateway (IGW)       |
              +-----------------+-----------------+
                                |
                    +-----------v-----------+
                    |   Public Route Table  |
                    +-----------+-----------+
                                |

+---------------------------------v----------------------------------+
| AWS VPC (10.0.0.0/16) - PCI-DSS Isolated                           |
|                                                                    |
|  +--------------------------------------------------------------+  |
|  | Web Tier Subnet (10.0.0.0/20)                               |  |
|  | [Web Security Group] -> Ingress: Port 443 (Corporate CIDR)   |  |
|  +------------------------------+-------------------------------+  |
|                                 | Security Group Chaining          |
|  +------------------------------v-------------------------------+  |
|  | App Tier Subnet (10.0.16.0/20)                              |  |
|  | [App Security Group] -> Ingress: Port 8080 (Strict Web-SG)   |  |
|  +------------------------------+-------------------------------+  |
|                                 | Security Group Chaining          |
|  +------------------------------v-------------------------------+  |
|  | Data Tier Subnet (10.0.32.0/20)                             |  |
|  | [Data Security Group] -> Ingress: Port 5432 (Strict App-SG)  |  |
|  +--------------------------------------------------------------+  |
+--------------------------------------------------------------------+
|
+-------------------------+-------------------------+
|                                                   |
v                                                   v
+-------------------+                               +-------------------+
| AWS KMS (CMK)     |                               | AWS S3 Audit Bucket|
| Automatic Key     |---- Enforces Encryption ----> | SEC Rule 17a-4    |
| Rotation (30 Day) |                               | WORM Compliance   |
+-------------------+                               +-------------------+

```

### Key Security & Governance Features
* **Zero-Trust Network Chaining:** Security groups utilize explicit cross-references (Web SG $\rightarrow$ App SG $\rightarrow$ Data SG) to prevent direct network access to data stores.
* **Immutable Audit Storage:** S3 Object Lock configured in `COMPLIANCE` mode enforcing strict WORM (Write Once, Read Many) retention for SEC 17a-4 regulatory alignment.
* **Key Governance:** Customer Managed Keys (CMK) configured with mandatory key rotation for envelope encryption across logs and storage objects.
* **Dynamic Compliance Guardrails:** Custom Python engine using `boto3` to perform post-deployment runtime validation of encryption and security group states.

---

## 🛠️ Repository Structure


```

├── .github/
│   └── workflows/
│       └── deploy.yml            # CI/CD Pipeline (Trivy + Terraform Validate)
├── environments/
│   └── dev/
│       ├── main.tf               # Root module & LocalStack endpoint mapping
│       ├── outputs.tf            # Deployment telemetry & outputs
│       └── variables.tf          # Environment inputs
├── modules/
│   └── aws_vpc/
│       ├── main.tf               # Core VPC, Subnets, SG Chaining, KMS, S3 WORM
│       ├── outputs.tf            # Exported module attributes
│       └── variables.tf          # Module configuration options
├── scripts/
│   ├── guardrail.py              # Boto3 runtime compliance verification engine
│   └── init_backend.py           # S3/DynamoDB state bootstrap script
├── docker-compose.yml            # LocalStack enterprise container configuration
└── Makefile                      # Developer speed-run & workflow automation

```

---

## 🚀 Quickstart & Local Execution

### Prerequisites
* Docker & Docker Compose
* Python 3.10+
* Terraform 1.5+ or `tflocal`
* `act` (Optional: for local GitHub Actions testing)

### Speed-Run Target Drills

1. **Boot Local Infrastructure & State Backend:**
   ```bash
   make up

```

*Spins up LocalStack containers, verifies gateway health, and initializes the S3 state bucket and DynamoDB lock table.*

2. **Run IaC Static Security Audit:**
```bash
make scan

```


*Executes Trivy security scanner against HCL modules to verify zero HIGH/CRITICAL vulnerabilities.*
3. **Provision AWS Infrastructure:**
```bash
make apply

```


*Performs `tflocal init`, plans execution, and provisions network and compliance modules locally.*
4. **Verify Runtime Compliance:**
```bash
make audit

```


*Executes `scripts/guardrail.py` to audit Object Lock, SSE-KMS, CMK key rotation, and SG chaining.*
5. **Test CI/CD Pipeline Offline:**
```bash
make act-test

```


