---
title: "FortiGate User Managed Scaling (UMS) on AWS"
linkTitle: "FortiGate UMS on AWS"
weight: 1
archetype: "home"
description: "Deploy a FortiManager-driven FortiGate User Managed Scaling group behind an AWS Gateway Load Balancer"
---

This guide deploys a **FortiGate User Managed Scaling (UMS)** group on AWS. FortiManager onboards, licenses (FortiFlex), configures and scales the FortiGates. The FortiGates sit behind an AWS **Gateway Load Balancer** (GENEVE) and inspect:

- **Centralized egress and east-west traffic** from spoke VPCs through a Transit Gateway
- **Distributed egress traffic** from VPCs that have their own Internet Gateway and a GWLB endpoint

Two Terraform templates build the deployment:

| Template | Purpose |
|---|---|
| `terraform/existing_vpc_resources` | Lab environment: inspection VPC, management VPC with FortiManager, Transit Gateway, spoke VPCs, distributed egress VPCs |
| `terraform/ums_template` | The FortiGate UMS group: Auto Scaling group, Gateway Load Balancer, GWLB endpoints, routes, and the FortiManager CLI template for the group |

Start with the [Introduction](1_introduction/).
