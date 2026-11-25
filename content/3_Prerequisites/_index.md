---
title: "Prerequisites"
menuTitle: "Prerequisites"
weight: 30
---

## Accounts and entitlements

- **AWS account** with permissions for EC2 (VPC, subnets, route tables, Internet and NAT Gateways, Elastic IPs, security groups, network interfaces, instances, Transit Gateway, VPC endpoints), Elastic Load Balancing, Auto Scaling, Lambda, DynamoDB, S3, EventBridge, CloudWatch Logs, IAM (roles, instance profiles, `iam:PassRole`).
- **AWS Marketplace subscriptions** (accept the terms once per account):
  - FortiGate Next-Generation Firewall **BYOL** (FortiFlex runs on the BYOL AMI)
  - FortiManager (BYOL, with a license file, or PAYG)
- **FortiCloud account** with a **FortiFlex** program: a program serial number, points, and a **configuration** for FortiGate-VM whose CPU count matches `fgt_instance_type` (for example 4 CPUs for `c6i.xlarge`).
- **FortiManager license** (BYOL) with enough device count for the largest instance count you plan. Firmware upgrades of the FortiGates through FortiManager need a valid firmware contract.

## Versions

| Product | Minimum |
|---|---|
| FortiOS | 7.6.4 (8.0 included) |
| FortiManager | 7.6.4 (8.0 included), and the same or a later version than the FortiGates |
| Terraform | 1.5 |
| Fortinet Terraform module | `fortinetdev/cloud-modules/aws` 1.1.7 (pinned in `ums_template`) |

`ums_template` refuses a `fortios_version` lower than 7.6.4. Set `fortimanager_os_version` in `existing_vpc_resources` to 7.6.4 or later, and to the same or a later version than `fortios_version`.

## FortiManager requirements

- A **fixed address**: an Elastic IP, or a fixed private IP (`fortimanager_host_ip`). The FortiGates store it at boot.
- `fgfm-allow-vm` enabled. The FortiManager that `existing_vpc_resources` builds sets it in its bootstrap configuration:

  ```
  config system global
      set fgfm-allow-vm enable
  end
  ```
- **TCP 541 (FGFM)** reachable from the FortiGates. See [FortiManager reachability](../2_architecture/#fortimanager-reachability).
- An **AWS identity** for FortiManager's AWS SDN connector, with permission to read the Auto Scaling group and change its instance counts. For example:

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:SetDesiredCapacity",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeRegions",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets"
        ],
        "Resource": "*"
      }
    ]
  }
  ```

  {{% notice note %}}
  Fortinet documents the requirement ("read and edit the Auto Scaling group properties") but not an exact action list. Check the SDN connector in FortiManager after you create it: the UMS group must show its instance counts.
  {{% /notice %}}

## Workstation

- Terraform 1.5 or later
- AWS CLI with credentials for the target account (`aws sts get-caller-identity` works)
- An EC2 key pair in the target region (`keypair`)
- Git, and a clone of this repository:

  ```bash
  git clone https://github.com/FortinetCloudCSE/AWS_User_Managed_Scaling.git
  ```

## Order of work

1. `existing_vpc_resources` (lab VPCs and FortiManager)
2. FortiFlex and FortiManager configuration
3. `ums_template` (FortiGates boot and register)
4. FortiManager: CLI template and policy package on the UMS group
