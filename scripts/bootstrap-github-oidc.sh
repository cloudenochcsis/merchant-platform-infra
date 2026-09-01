#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-github-oidc.sh --region REGION --bucket NAME --table NAME [options]

Options:
  --state-key KEY   Terraform state key (default: axis/dev/terraform.tfstate)
  --role-name NAME  GitHub deployment role name (default: axis-dev-github-terraform)
  --help, -h        Show this help message
EOF
}

aws_region=""
bucket_name=""
table_name=""
state_key="axis/dev/terraform.tfstate"
role_name="axis-dev-github-terraform"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)
      aws_region="${2:-}"
      shift 2
      ;;
    --bucket)
      bucket_name="${2:-}"
      shift 2
      ;;
    --table)
      table_name="${2:-}"
      shift 2
      ;;
    --state-key)
      state_key="${2:-}"
      shift 2
      ;;
    --role-name)
      role_name="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${aws_region}" || -z "${bucket_name}" || -z "${table_name}" || -z "${state_key}" || -z "${role_name}" ]]; then
  usage >&2
  exit 1
fi

if ! command -v aws > /dev/null 2>&1; then
  printf 'AWS CLI is required.\n' >&2
  exit 1
fi

github_oidc_url="https://token.actions.githubusercontent.com"
github_oidc_host="token.actions.githubusercontent.com"
github_subject="repo:cloudenochcsis@155973884/merchant-platform-infra@1352702887:ref:refs/heads/main"

account_id="$(aws sts get-caller-identity --query Account --output text)"
oidc_provider_arn="arn:aws:iam::${account_id}:oidc-provider/${github_oidc_host}"
role_arn="arn:aws:iam::${account_id}:role/${role_name}"

temporary_directory="$(mktemp -d)"
trap 'rm -rf "${temporary_directory}"' EXIT
trust_policy_path="${temporary_directory}/trust-policy.json"
permission_policy_path="${temporary_directory}/permission-policy.json"

cat > "${trust_policy_path}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsTrust",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${github_oidc_host}:aud": "sts.amazonaws.com",
          "${github_oidc_host}:sub": "${github_subject}"
        }
      }
    }
  ]
}
EOF

printf 'Using AWS account %s.\n' "${account_id}"

if aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn "${oidc_provider_arn}" > /dev/null 2>&1; then
  printf 'GitHub OIDC provider already exists.\n'
else
  printf 'Creating GitHub OIDC provider.\n'
  aws iam create-open-id-connect-provider \
    --url "${github_oidc_url}" \
    --client-id-list "sts.amazonaws.com" > /dev/null
fi

if aws iam get-role --role-name "${role_name}" > /dev/null 2>&1; then
  printf 'Updating role trust policy: %s\n' "${role_name}"
  aws iam update-assume-role-policy \
    --role-name "${role_name}" \
    --policy-document "file://${trust_policy_path}"
else
  printf 'Creating role: %s\n' "${role_name}"
  aws iam create-role \
    --role-name "${role_name}" \
    --description "Terraform deployment role for merchant-platform-infra" \
    --assume-role-policy-document "file://${trust_policy_path}" \
    --max-session-duration 3600 \
    --tags Key=Project,Value=axis Key=Environment,Value=dev > /dev/null
fi

cat > "${permission_policy_path}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StateBucketMetadata",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning"
      ],
      "Resource": "arn:aws:s3:::${bucket_name}"
    },
    {
      "Sid": "ListStateObjects",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${bucket_name}",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "${state_key}",
            "${state_key}.tflock"
          ]
        }
      }
    },
    {
      "Sid": "StateObjects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${bucket_name}/${state_key}",
        "arn:aws:s3:::${bucket_name}/${state_key}.tflock"
      ]
    },
    {
      "Sid": "StateLocks",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:${aws_region}:${account_id}:table/${table_name}"
    },
    {
      "Sid": "CallerIdentity",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    },
    {
      "Sid": "RegionalRead",
      "Effect": "Allow",
      "Action": [
        "acm:DescribeCertificate",
        "acm:ListCertificates",
        "acm:ListTagsForCertificate",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListTagsForResource",
        "ec2:Describe*",
        "ecs:Describe*",
        "ecs:List*",
        "elasticloadbalancing:Describe*",
        "logs:DescribeLogGroups",
        "logs:ListTagsForResource",
        "rds:Describe*",
        "rds:ListTagsForResource",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "${aws_region}"
        }
      }
    },
    {
      "Sid": "RegionalMutations",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:DeleteAlarms",
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:TagResource",
        "cloudwatch:UntagResource",
        "ec2:AllocateAddress",
        "ec2:AssociateRouteTable",
        "ec2:AttachInternetGateway",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateInternetGateway",
        "ec2:CreateNatGateway",
        "ec2:CreateRoute",
        "ec2:CreateRouteTable",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSubnet",
        "ec2:CreateTags",
        "ec2:CreateVpc",
        "ec2:DeleteInternetGateway",
        "ec2:DeleteNatGateway",
        "ec2:DeleteRoute",
        "ec2:DeleteRouteTable",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSubnet",
        "ec2:DeleteTags",
        "ec2:DeleteVpc",
        "ec2:DetachInternetGateway",
        "ec2:DisassociateRouteTable",
        "ec2:ModifySecurityGroupRules",
        "ec2:ModifySubnetAttribute",
        "ec2:ModifyVpcAttribute",
        "ec2:ReleaseAddress",
        "ec2:ReplaceRoute",
        "ec2:ReplaceRouteTableAssociation",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ecs:CreateCluster",
        "ecs:CreateService",
        "ecs:DeleteCluster",
        "ecs:DeleteService",
        "ecs:DeregisterTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:TagResource",
        "ecs:UntagResource",
        "ecs:UpdateClusterSettings",
        "ecs:UpdateService",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:RemoveTags",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DeleteRetentionPolicy",
        "logs:PutRetentionPolicy",
        "logs:TagLogGroup",
        "logs:TagResource",
        "logs:UntagLogGroup",
        "logs:UntagResource",
        "rds:AddTagsToResource",
        "rds:CreateDBInstance",
        "rds:CreateDBSubnetGroup",
        "rds:DeleteDBInstance",
        "rds:DeleteDBSubnetGroup",
        "rds:ModifyDBInstance",
        "rds:ModifyDBSubnetGroup",
        "rds:RemoveTagsFromResource",
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource",
        "secretsmanager:UpdateSecret",
        "secretsmanager:UpdateSecretVersionStage"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "${aws_region}"
        }
      }
    },
    {
      "Sid": "ApplicationRoleManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfilesForRole",
        "iam:ListRolePolicies",
        "iam:ListRoleTags",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:UpdateAssumeRolePolicy"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:role/axis-dev-ecs-execution",
        "arn:aws:iam::${account_id}:role/axis-dev-ecs-task"
      ]
    },
    {
      "Sid": "ExecutionPolicyAttachment",
      "Effect": "Allow",
      "Action": [
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy"
      ],
      "Resource": "arn:aws:iam::${account_id}:role/axis-dev-ecs-execution",
      "Condition": {
        "ArnEquals": {
          "iam:PolicyARN": "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
        }
      }
    },
    {
      "Sid": "ReadExecutionPolicy",
      "Effect": "Allow",
      "Action": [
        "iam:GetPolicy",
        "iam:GetPolicyVersion"
      ],
      "Resource": "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    },
    {
      "Sid": "PassApplicationRoles",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::${account_id}:role/axis-dev-ecs-execution",
        "arn:aws:iam::${account_id}:role/axis-dev-ecs-task"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    },
    {
      "Sid": "RequiredServiceLinkedRoles",
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": [
            "ecs.amazonaws.com",
            "elasticloadbalancing.amazonaws.com",
            "rds.amazonaws.com"
          ]
        }
      }
    }
  ]
}
EOF

printf 'Applying scoped Terraform permissions.\n'
aws iam put-role-policy \
  --role-name "${role_name}" \
  --policy-name "axis-dev-terraform-deployment" \
  --policy-document "file://${permission_policy_path}"

printf '\nGitHub repository variables:\n'
printf 'AWS_REGION=%s\n' "${aws_region}"
printf 'AWS_ROLE_ARN=%s\n' "${role_arn}"
printf 'TF_BACKEND_BUCKET=%s\n' "${bucket_name}"
printf 'TF_BACKEND_KEY=%s\n' "${state_key}"
printf 'TF_BACKEND_DYNAMODB_TABLE=%s\n' "${table_name}"
printf '\nConfigure TFVARS_DEV separately as a GitHub repository secret.\n'
