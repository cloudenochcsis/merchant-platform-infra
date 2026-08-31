# Architecture

```mermaid
flowchart LR
    Internet((Internet))

    subgraph AWS[AWS Region]
        direction LR

        subgraph VPC[VPC]
            direction LR

            subgraph AZA[Availability Zone A]
                direction TB

                subgraph PublicA[Public subnet A]
                    ALBA[ALB node A<br/>same logical ALB]
                    NAT[NAT Gateway + EIP<br/>single-AZ dependency]
                end

                subgraph ApplicationA[Private application subnet A]
                    ECSA[ECS task A<br/>Fargate - no public IP]
                end

                subgraph DatabaseA[Private database subnet A]
                    RDSA[(RDS PostgreSQL primary<br/>encrypted and private<br/>placement illustrative)]
                end
            end

            subgraph AZB[Availability Zone B]
                direction TB

                subgraph PublicB[Public subnet B]
                    ALBB[ALB node B<br/>same logical ALB]
                end

                subgraph ApplicationB[Private application subnet B]
                    ECSB[ECS task B<br/>Fargate - no public IP]
                end

                subgraph DatabaseB[Private database subnet B]
                    RDSB[(Multi-AZ standby<br/>disabled in dev)]
                end
            end
        end

        Secrets[(Secrets Manager<br/>database credentials)]
        Logs[(CloudWatch Logs)]
        Alarms[CloudWatch alarms<br/>ALB, ECS, and RDS]
    end

    Internet -->|HTTPS 443| ALBA
    Internet -->|HTTPS 443| ALBB
    Internet -. HTTP 80 redirect .-> ALBA
    Internet -. HTTP 80 redirect .-> ALBB

    ALBA -->|container port| ECSA
    ALBB -->|container port| ECSB
    ECSA -->|PostgreSQL 5432| RDSA
    ECSB -->|PostgreSQL 5432| RDSA

    ECSA -->|HTTPS egress| NAT
    ECSB -->|cross-AZ HTTPS egress| NAT
    NAT --> Internet

    Secrets -->|inject credentials| ECSA
    Secrets -->|inject credentials| ECSB
    ECSA -->|awslogs| Logs
    ECSB -->|awslogs| Logs
    ALBA -. metrics .-> Alarms
    ALBB -. metrics .-> Alarms
    ECSA -. metrics .-> Alarms
    ECSB -. metrics .-> Alarms
    RDSA -. metrics .-> Alarms

    RDSA -. Multi-AZ replication when enabled .-> RDSB

    classDef optional fill:#f7f7f7,stroke:#888,stroke-dasharray:5 5,color:#555;
    class RDSB optional;
```

The two ALB nodes represent one logical Application Load Balancer spanning both public subnets. The two tasks represent the ECS service's default desired count of two with Availability Zone rebalancing enabled. Security groups restrict ALB-to-task traffic to the container port and task-to-database traffic to PostgreSQL 5432.

The RDS primary placement is illustrative because AWS selects a subnet from the database subnet group. The dev example sets `db_multi_az = false`, so the dashed standby is not deployed unless Multi-AZ is enabled. Both database subnets have no default internet route. The single NAT Gateway in AZ A is an intentional cost trade-off and an outbound dependency for tasks in both AZs.
