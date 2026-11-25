---
title: "existing_vpc_resources"
menuTitle: "existing_vpc_resources"
weight: 51
---

`existing_vpc_resources` builds the lab around the UMS group. In a customer environment the inspection VPC, Transit Gateway and spokes already exist: tag them with `Fortinet-Role` tags and skip the parts of this template that build them.

## What it builds

| Variable | Builds |
|---|---|
| `enable_build_inspection_vpc` | Inspection VPC: public, GWLB endpoint, private subnets per AZ, Internet Gateway, `Fortinet-Role` tags |
| `create_nat_gateway_subnets` | NAT Gateway subnets in the inspection VPC (pair with `access_internet_mode = "nat_gw"` in `ums_template`) |
| `create_management_subnet_in_inspection_vpc` | Management subnets in the inspection VPC (pair with `enable_dedicated_management_eni` in `ums_template`) |
| `enable_build_management_vpc` | Management VPC with public and private subnets |
| `enable_fortimanager` | FortiManager in the management VPC (required for UMS unless you use an existing FortiManager) |
| `enable_fortianalyzer`, `enable_jump_box` | Optional FortiAnalyzer and Linux jump box in the management VPC |
| `enable_build_existing_subnets` | Transit Gateway and the east and west spoke VPCs |
| `enable_linux_spoke_instances` | Linux traffic generators in the spoke VPCs |
| `enable_build_distributed_egress_vpcs` | Two distributed egress VPCs (`vpc_cidr_distributed_1`, `vpc_cidr_distributed_2`), each with an Internet Gateway, a GWLB endpoint subnet and a Linux instance |

## Configure

```bash
cd terraform/existing_vpc_resources
cp terraform.tfvars.example terraform.tfvars
```

Set at least:

| Variable | Value |
|---|---|
| `aws_region`, `availability_zone_1`, `availability_zone_2` (`availability_zone_3` optional) | Target region and AZ letters |
| `cp`, `env` | Naming prefix. Use the same values in `ums_template` |
| `keypair` | An EC2 key pair in the region |
| `management_cidr_sg` | Admin source CIDRs for FortiManager, the jump box and FortiAnalyzer |
| `fortimanager_os_version` | `7.6.8` or later (7.6), or `8.0.2` or later |
| `fortimanager_license_file` | Path to the FortiManager BYOL license, or `""` for PAYG |
| `fortimanager_admin_password` | FortiManager `admin` password |
| `enable_fortimanager_public_ip` | `true` for the internet reachability model (Elastic IP) |
| `fgfm_additional_source_cidrs` | Sources allowed to reach FortiManager on TCP 541 besides the inspection and management VPCs. The lab default is `["0.0.0.0/0"]` |
| `create_nat_gateway_subnets` | `true` to match `access_internet_mode = "nat_gw"` |
| `enable_build_distributed_egress_vpcs` | `true` to build the distributed egress VPCs |

Place the FortiManager license file in `licenses/` (the directory is not in Git: `*.lic` is ignored).

The FortiManager bootstrap configuration (`config_templates/fmgr-userdata.tftpl`) sets the hostname, the `admin` password, ADOMs, and `set fgfm-allow-vm enable`.

## Deploy

```bash
terraform init
terraform plan -out tfplan_evr
terraform apply tfplan_evr
```

Note the outputs that the next steps need:

```bash
terraform output fortimanager_public_ip
terraform output fortimanager_private_ip
terraform output jump_box_public_ip
```

FortiManager takes several minutes to boot and apply its license. Then continue with [FortiManager Configuration](../../4_fortimanager/).

## Verify

`verify_scripts/` checks the VPCs, subnets, routes and tags this template built:

```bash
cd verify_scripts
./verify_all.sh
```

## Using an existing FortiManager

Set `enable_fortimanager = false` and give the existing FortiManager's address to `ums_template` (`fortimanager_ip`). It must meet the [FortiManager requirements](../../3_prerequisites/#fortimanager-requirements): version, fixed address, `fgfm-allow-vm`, and TCP 541 open from the FortiGates.
