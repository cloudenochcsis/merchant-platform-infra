# Merchant Platform Infrastructure

This repository defines a small production-oriented AWS baseline for a containerised web application. It is intentionally straightforward: local Terraform modules, two Availability Zones, private compute and database tiers, and no deployment automation hidden from the reviewer.

Terraform has not been applied by this repository build.

## Architecture

```text
Internet
  -> public Application Load Balancer (HTTP redirects to HTTPS)
  -> ECS Fargate service in private application subnets
  -> PostgreSQL RDS in isolated private database subnets
```

The ALB spans two public subnets. ECS tasks span two private application subnets and receive no public IPs. RDS uses two private database subnets with no internet route and is never publicly accessible. See [architecture.md](architecture.md) for the diagram.

## Modules

- `network`: VPC, two subnets per tier, internet gateway, configurable shared or per-AZ NAT Gateways, route tables, and RDS subnet group.
- `security`: separate ALB, application, and database security groups with referenced inter-tier rules.
- `rds`: generated database password, Secrets Manager secret, and encrypted PostgreSQL RDS instance.
- `ecs`: ALB/listeners/target group, ECS cluster, Fargate task and service, IAM roles, and retained CloudWatch log group.
- `observability`: alarms for unhealthy ALB targets, ECS CPU, ECS memory, and low RDS free storage.

## Why ECS Fargate

ECS Fargate fits the initial small web workload without introducing an EC2 fleet or Kubernetes control plane to patch, scale, and operate. It retains native integration with ALB health checks, IAM roles, Secrets Manager, CloudWatch Logs, and rolling deployments while keeping the compute layer easy to review. The trade-off is less host-level control and potentially higher steady-state unit cost than a well-utilised EC2 fleet; those costs should be reconsidered when workload shape and scale are known.

## Prerequisites

- Terraform `~> 1.15.0`.
- AWS credentials with permission to read/write the remote state and manage the resources in this stack.
- An ACM certificate in the deployment Region. Supply its ARN through `certificate_arn`.
- A real application image with an immutable tag or digest. It must listen on `container_port`, respond successfully on `health_check_path`, and run as UID/GID `10001` with a read-only root filesystem.
- A separately bootstrapped, versioned, encrypted S3 state bucket and DynamoDB lock table.

Copy the example and replace its documentation-only image and certificate values:

```bash
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
```

## Assumptions

- DNS and certificate lifecycle are managed outside this stack. A valid ACM certificate must already exist in the target Region and be supplied through `certificate_arn`. This stack does not manage ACM certificates or Route 53 hosted zones.
- The application build and registry pipeline exists separately. A deployable container image must be available before `terraform apply`, preferably referenced by digest or by a registry-enforced immutable tag.
- Only the dev environment is implemented. Additional environments may initially share an AWS account for this demo, but production environments should preferably use separate accounts, credentials, and Terraform state.
- Initial traffic is low. The example sizing—`db.t4g.micro`, 0.25 vCPU and 512 MiB Fargate tasks, and `desired_count = 2`—is a starting point configured per environment, not an architectural limit.
- The encrypted S3 state bucket and DynamoDB lock table are bootstrapped separately before this stack is initialized. Their environment-specific values are supplied through backend configuration.
- Operators authenticate using appropriately scoped AWS credentials. Local credential provisioning is outside this stack; GitHub Actions uses the separately configured OIDC role described in the GitHub Actions Fallback section.

## Remote State

The root uses a partial S3 backend so account-specific state names are not committed. Create the encrypted S3 bucket and DynamoDB table once in a separate bootstrap process; do not add them to this stack because Terraform cannot safely store its state in infrastructure that does not exist yet. Configure the table with a string partition key named `LockID`, on-demand billing, point-in-time recovery, and encryption.

With an authenticated AWS CLI, bootstrap both resources once. The bucket name must be globally unique:

```bash
./scripts/bootstrap-backend.sh \
  --bucket REPLACE_STATE_BUCKET \
  --table REPLACE_LOCK_TABLE \
  --region eu-west-1
```

The script is safe to rerun: it creates missing resources, then enforces bucket versioning, SSE-S3 encryption, public-access blocking, DynamoDB encryption, and point-in-time recovery. It does not create state objects, IAM policies, or KMS keys.

Initialize with environment-specific backend values:

```bash
terraform -chdir=environments/dev init -reconfigure \
  -backend-config="bucket=REPLACE_STATE_BUCKET" \
  -backend-config="key=axis/dev/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="dynamodb_table=REPLACE_LOCK_TABLE" \
  -backend-config="encrypt=true"
```

Enable bucket versioning, block public access, restrict state-path IAM permissions, and use a KMS key where policy requires one. Current Terraform versions deprecate DynamoDB locking in favour of S3 native lockfiles. DynamoDB remains here because it is explicit in the assessment brief; migrate the bootstrap and backend to `use_lockfile = true` as a controlled follow-up.

## Validate and Plan

```bash
terraform fmt -check -recursive
terraform -chdir=environments/dev validate
terraform -chdir=environments/dev test
terraform -chdir=environments/dev plan -out=dev.tfplan
terraform -chdir=environments/dev show dev.tfplan
```

Review the saved plan before any controlled apply. The test uses mocked providers and creates no AWS resources. A real plan requires valid AWS credentials, backend values, an ACM certificate ARN, and an application image value. Infrastructure was not applied while building this repository; both local and GitHub applies require an explicit operator action.

## GitHub Actions Fallback

`.github/workflows/terraform.yml` provides a deliberately manual fallback for the dev stack. Pull requests only run formatting, backend-free initialization, validation, mocked Terraform tests, and a Checkov security scan. They never authenticate to AWS or provision resources.

Checkov is pinned to a reviewed action version and scans all Terraform. Known findings for documented deferred controls and cross-module security-group attachment false positives remain visible but do not fail the workflow; any other failed policy blocks validation. The allowlist should shrink as those controls are implemented.

Manual runs accept an operation of `plan` or `apply`. An apply also requires `confirm_apply` to be exactly `apply`. The workflow creates a saved plan and applies that exact file on the same ephemeral runner; it does not upload the potentially sensitive plan as an artifact.

Configure these GitHub Actions repository variables:

- `AWS_REGION`
- `AWS_ROLE_ARN`
- `TF_BACKEND_BUCKET`
- `TF_BACKEND_KEY`
- `TF_BACKEND_DYNAMODB_TABLE`

Configure `TFVARS_DEV` as a repository secret containing the complete HCL content of a real `environments/dev/terraform.tfvars`, based on `terraform.tfvars.example`. Do not put database credentials in this secret.

Before running the workflow, create GitHub's OIDC identity provider and a dedicated IAM role in AWS outside this stack. Restrict the role trust policy to this repository, and grant only the state-path, lock-table, and infrastructure permissions the dev stack requires. The workflow requests short-lived credentials with `id-token: write`; it does not use AWS access-key secrets.

Run the workflow from **Actions → Terraform → Run workflow**. Use `plan` first. For provisioning, run it again with `apply` and enter `apply` in the confirmation field. Nothing applies automatically after a push or merge.

Local Terraform and GitHub Actions must use the same backend bucket, key, Region, and lock table. This keeps both execution paths on one state and prevents concurrent state writes. The backend, OIDC provider and role, ACM certificate, and application image remain external prerequisites.

## Secrets

Terraform generates a 32-character database password and stores a JSON credential document in Secrets Manager. ECS injects the `username` and `password` JSON keys at task startup. The execution role can read only that secret; the application task role has no permissions because the sample application needs none.

No password or secret value is committed or output. Because Terraform creates the secret version, the password is still present as sensitive data in Terraform state. The state bucket therefore requires encryption, versioning, narrowly scoped IAM, access logging, and no public access.

For the current Terraform-managed approach, rotate credentials in a reviewed maintenance change:

```bash
terraform -chdir=environments/dev apply -replace=module.rds.random_password.database
aws ecs update-service \
  --region REPLACE_REGION \
  --cluster REPLACE_CLUSTER \
  --service REPLACE_SERVICE \
  --force-new-deployment
```

The replacement updates the RDS password and secret version. The forced deployment replaces existing tasks so they read the new secret. Automating rotation with a Secrets Manager rotation Lambda is a reasonable next step, but ownership of password changes must first move out of Terraform to avoid drift and password rollback.

## Security and Availability Decisions

- Only ALB ports 80 and 443 accept internet traffic. Port 80 performs a permanent HTTPS redirect.
- ALB-to-application traffic is limited to `container_port` by security-group reference.
- Application-to-RDS traffic is limited to TCP 5432 by security-group reference.
- ECS tasks have no public IPs. Their HTTPS egress uses NAT for image pulls, logs, and secret retrieval.
- RDS is private, encrypted with an AWS-managed storage key, backup-enabled, and deletion-protected by default.
- ALB and ECS span two Availability Zones. RDS Multi-AZ defaults to enabled but the dev example disables it to control cost.
- All resources use `Project`, `Environment`, `ManagedBy`, and `Component` tags.

One NAT Gateway is the deliberate dev cost-saving exception. With `nat_gateway_per_az = false`, both application subnet route tables depend on the NAT in the first Availability Zone, making outbound application startup dependencies vulnerable to that AZ. Set `nat_gateway_per_az = true` for production to create one gateway per AZ and route each private application subnet through its local gateway.

## Availability Zone Failure and Recovery

The ALB stops routing to unhealthy targets in a failed Availability Zone. ECS uses two private application subnets, a default desired count of two, and Availability Zone rebalancing; it can replace failed tasks in the surviving zone, subject to regional Fargate capacity and working outbound access.

RDS provides automatic cross-AZ failover only when `db_multi_az` is enabled. The module defaults it to true, but the dev example disables it for cost, so dev can remain unavailable during a database AZ outage until AWS service recovery or a restore. Production should enable Multi-AZ and regularly test database restore procedures.

The dev single NAT Gateway is the main shared AZ dependency: if its Availability Zone fails, existing healthy tasks may continue serving traffic and reaching RDS, but image pulls and calls to ECR, CloudWatch Logs, and Secrets Manager can fail. Production should set `nat_gateway_per_az = true`, or use carefully selected VPC endpoints that remove those NAT dependencies.

## Cost Management

Reduce cost first through measured right-sizing of Fargate CPU and memory, RDS instance and storage settings, backup retention, and log retention. Keep at least two production tasks so savings do not remove application AZ redundancy. After usage stabilises, evaluate Compute Savings Plans, RDS Reserved Instances, and ARM64-compatible application images. Compare NAT processing and cross-AZ charges with the fixed hourly cost of VPC endpoints; an S3 gateway endpoint is a low-cost first step, while interface endpoints should be added only where traffic and resilience justify them. Single-NAT and non-Multi-AZ settings are acceptable for dev, not production defaults.

## ECS Deployments and Rollback

Changing the immutable image reference creates a new task-definition revision. ECS performs a rolling deployment with 100% minimum and 200% maximum healthy capacity. The ALB health check gates traffic; ECS ignores initial load-balancer failures during the grace period. The deployment circuit breaker automatically rolls back a deployment that cannot reach steady state.

An operational rollback pins `container_image` to the previously approved tag or digest and applies the reviewed plan. CloudWatch alarms provide signals but are intentionally not wired to deployment actions in this small baseline.

## Environments

`environments/dev` is an explicit root composition. Add `environments/staging` and `environments/prod` as separate root modules that call the same local network, security, RDS, ECS, and observability modules; do not copy the module implementations. Each environment has its own variable values, credentials or assume-role target, and backend state key, such as `axis/staging/terraform.tfstate` or `axis/prod/terraform.tfstate`. Do not share Terraform state across environments.

Production should set `nat_gateway_per_az = true` and `db_multi_az = true`, retain `db_deletion_protection = true`, and choose `desired_count`, `db_instance_class`, `db_backup_retention_days`, and `log_retention_days` for measured demand and recovery requirements. Promote reviewed immutable image references and equivalent Terraform changes between environments rather than sharing environment-specific state or values.

## Remaining Risks

- The dev values use one NAT Gateway and disable RDS Multi-AZ; neither choice provides full AZ resilience.
- Alarm actions default to an empty list, so alarms are created but do not notify an operator until an SNS or incident-management destination is supplied.
- ECS has a fixed desired count and no target-tracking autoscaling policy.
- Database credentials remain in encrypted Terraform state and rotation is a reviewed manual operation.
- ACM lifecycle, DNS, WAF, VPC endpoints, and centralised log analysis are outside this baseline.
- Checkov provides static source analysis only. Its soft-fail allowlist covers documented deferred controls and cross-module false positives; it does not verify deployed AWS state or organisation-specific policy and should be reduced as controls are implemented.
- The design is single-Region and has no implemented cross-Region backup or disaster-recovery path.
- The remote-state resources and GitHub OIDC deployment role are external prerequisites whose configuration must be reviewed separately.
- Terraform has been validated and tested with mocked providers, but no environment-specific plan or apply has verified quotas, permissions, certificate ownership, or service availability in a real AWS account.

See [improvements.md](improvements.md) for intentionally deferred controls.
