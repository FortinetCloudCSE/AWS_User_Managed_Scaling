---
title: "Introduction"
menuTitle: "Introduction"
weight: 10
---

## What is User Managed Scaling

User Managed Scaling (UMS) is a FortiManager feature for FortiGate-VM groups in public clouds. The FortiManager administrator sets the instance count of the group, and FortiManager:

- **Scales** the group: FortiManager's AWS SDN connector changes the instance count of the AWS Auto Scaling group.
- **Onboards** each new FortiGate: an auto-onboarding rule authorizes it into an ADOM and a device group.
- **Licenses** each new FortiGate with FortiFlex, through FortiManager's FortiFlex connector.
- **Configures** each new FortiGate with the CLI templates, system templates and policy package assigned to the group.

Scaling is an administrator decision in FortiManager (for example, before a known traffic peak). It is not driven by CloudWatch CPU alarms.

## What this guide deploys

This repository wraps the Fortinet Terraform module [`fortinetdev/cloud-modules/aws`](https://registry.terraform.io/modules/fortinetdev/cloud-modules/aws/latest) (example `spk_tgw_gwlb_asg_fgt_igw`, version `1.1.7`) with UMS turned on, and adds the surrounding lab:

- An **inspection VPC** with a **Gateway Load Balancer**. The FortiGates terminate one GENEVE tunnel per Availability Zone.
- **Centralized egress**: spoke VPCs (east and west) attached to a **Transit Gateway**, with internet-bound and east-west traffic sent through the inspection VPC.
- **Distributed egress**: VPCs with their own Internet Gateway and a **GWLB endpoint** that sends their traffic to the same FortiGates, without a Transit Gateway hop.
- A **management VPC** with **FortiManager**, the control plane of the UMS group.

## Requirements at a glance

| Item | Requirement |
|---|---|
| FortiOS | 7.6.4 or later (8.0 included) |
| FortiManager | 7.6.4 or later (8.0 included), and the same or a later version than the FortiGates |
| Licensing | FortiFlex, through FortiManager's FortiFlex connector |
| FortiManager address | Fixed (Elastic IP or fixed private IP), reachable from the FortiGates on TCP 541 |
| Terraform | 1.5 or later, AWS provider credentials for the target account |

## How to use this guide

1. [Architecture](2_architecture/): how traffic flows and how UMS works on AWS
2. [Prerequisites](3_prerequisites/): accounts, versions, permissions
3. [FortiManager Configuration](4_fortimanager/): FortiFlex and FortiManager setup, done before the FortiGates boot
4. [Deployment](5_deployment/): the two templates, then the configuration of the UMS group
5. [Scaling](6_scaling/), [Licensing](7_licensing/), [Upgrades](8_upgrades/), [Cleanup](9_cleanup/)
