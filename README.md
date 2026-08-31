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

- `network`: VPC, two subnets per tier, internet gateway, one NAT Gateway, route tables, and RDS subnet group.
- `security`: separate ALB, application, and database security groups with referenced inter-tier rules.
- `rds`: generated database password, Secrets Manager secret, and encrypted PostgreSQL RDS instance.
- `ecs`: ALB/listeners/target group, ECS cluster, Fargate task and service, IAM roles, and retained CloudWatch log group.
- `observability`: alarms for unhealthy ALB targets, ECS CPU, ECS memory, and low RDS free storage.

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

## Remote State

The root uses a partial S3 backend so account-specific state names are not committed. Create the encrypted S3 bucket and DynamoDB table once in a separate bootstrap process; do not add them to this stack because Terraform cannot safely store its state in infrastructure that does not exist yet. Configure the table with a string partition key named `LockID`, on-demand billing, point-in-time recovery, and encryption.

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

`.github/workflows/terraform.yml` provides a deliberately manual fallback for the dev stack. Pull requests only run formatting, backend-free initialization, validation, and mocked Terraform tests. They never authenticate to AWS or provision resources.

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

One NAT Gateway is the deliberate cost-saving exception. Both application subnet route tables depend on the NAT in the first Availability Zone, making outbound application startup dependencies vulnerable to that AZ. A production environment should use one NAT Gateway per AZ with each private route table targeting its local gateway.

## ECS Deployments and Rollback

Changing the immutable image reference creates a new task-definition revision. ECS performs a rolling deployment with 100% minimum and 200% maximum healthy capacity. The ALB health check gates traffic; ECS ignores initial load-balancer failures during the grace period. The deployment circuit breaker automatically rolls back a deployment that cannot reach steady state.

An operational rollback pins `container_image` to the previously approved tag or digest and applies the reviewed plan. CloudWatch alarms provide signals but are intentionally not wired to deployment actions in this small baseline.

## Environments

`environments/dev` is an explicit root composition. Create `environments/staging` and `environments/prod` with the same module calls, separate variable values, separate state keys, and preferably separate AWS accounts/assume-role targets. Do not share Terraform state across environments. Production values should retain deletion protection and Multi-AZ and normally increase task count, database sizing, backup retention, and log retention.

See [improvements.md](improvements.md) for intentionally deferred controls.
