# Improvements

- **One NAT Gateway per Availability Zone:** remove the single-AZ application egress dependency and avoid cross-AZ NAT traffic.
- **RDS resilience based on measured demand:** retain Multi-AZ for production and add read replicas only when availability or read scaling justifies their cost.
- **Managed DNS and edge protection:** add Route 53, ACM certificate lifecycle, HTTPS-only policy enforcement, and AWS WAF when the platform has a real domain and threat model.
- **VPC endpoints:** use interface endpoints for ECR, CloudWatch Logs, and Secrets Manager plus an S3 gateway endpoint to reduce NAT dependence and keep AWS-service traffic private.
- **Stronger CI/CD controls:** reduce the Checkov soft-fail allowlist as controls are implemented, add organisation-specific policies and reviewed plan summaries, publish immutable application images, and support automated rollback.
- **Centralised operations:** route alarms to an owned on-call destination, centralise logs, define dashboards and service-level indicators, and set retention by compliance requirements.
- **Backup and disaster-recovery testing:** add AWS Backup policies where appropriate, cross-Region or cross-account copies for critical data, restore exercises, and documented recovery objectives.
- **Automated secret rotation:** move password ownership from Terraform to Secrets Manager rotation, coordinate database updates, and force ECS task replacement after successful rotation.
- **Native S3 state locking:** migrate from deprecated DynamoDB locking to the S3 backend `use_lockfile` mechanism after confirming all operators use a compatible Terraform version.
