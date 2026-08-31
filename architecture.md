# Architecture

```mermaid
flowchart TB
    Internet((Internet))
    Logs[(CloudWatch Logs)]

    subgraph VPC[VPC across two Availability Zones]
        subgraph Public[Public subnets - AZ A and AZ B]
            ALB[Application Load Balancer<br/>HTTP redirect + HTTPS listener]
            NAT[NAT Gateway(s)<br/>shared in dev or one per AZ]
        end

        subgraph Application[Private application subnets - AZ A and AZ B]
            ECS[ECS Fargate service<br/>no public IPs]
        end

        subgraph Database[Private database subnets - AZ A and AZ B]
            RDS[(Encrypted PostgreSQL RDS<br/>not publicly accessible)]
        end
    end

    Internet -->|HTTPS 443| ALB
    Internet -. HTTP 80 redirects .-> ALB
    ALB -->|container port| ECS
    ECS -->|PostgreSQL 5432| RDS
    ECS -->|HTTPS egress| NAT
    NAT --> Internet
    ECS -->|awslogs| Logs
```

Security groups enforce the three solid application traffic paths. Database subnets have no default internet route. The dotted HTTP path terminates in a redirect and does not reach the application.
