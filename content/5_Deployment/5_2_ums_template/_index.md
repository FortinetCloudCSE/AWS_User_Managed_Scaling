---
title: "ums_template"
menuTitle: "ums_template"
weight: 52
---

`ums_template` deploys the FortiGate UMS group into the inspection VPC. It calls the Fortinet module `fortinetdev/cloud-modules/aws//examples/spk_tgw_gwlb_asg_fgt_igw` (version `1.1.7`) with FortiManager integration in UMS mode, and adds the routes of the Transit Gateway, inspection VPC and distributed egress VPCs.

{{% notice warning %}}
Finish [FortiManager Configuration](../../4_fortimanager/) first. Each FortiGate registers to FortiManager once, at first boot.
{{% /notice %}}

## What it builds

- Gateway Load Balancer (`<asg_module_prefix>-gwlb-fgt`), GENEVE target group, listener, endpoint service
- GWLB endpoints in the inspection VPC (`<asg_module_prefix>-gwlbe_az1`, ...) and, with `enable_distributed_egress`, in each distributed egress VPC
- Auto Scaling group `<asg_module_prefix>-fgt_ums_asg` and launch template `<asg_module_prefix>-fgt_ums_template` (FortiGate BYOL AMI of `fortios_version`)
- Lambda function, EventBridge rules and DynamoDB table `<asg_module_prefix>-fgt_ums_track_table` for the instance lifecycle
- Routes: Transit Gateway attachment subnets and private subnets to the GWLB endpoints; distributed VPC workload subnets and Internet Gateway ingress route tables to their GWLB endpoints
- `fortimanager/fmg-cli-template.txt` and `fortimanager/fmg-policy-reference.txt`: the FortiManager configuration of the group, with this deployment's GWLB addresses

It creates no CloudWatch scaling alarms or policies: FortiManager sets the instance count.

## Configure

```bash
cd terraform/ums_template
cp terraform.tfvars.example terraform.tfvars
```

### Values that must match existing_vpc_resources

| `ums_template` | `existing_vpc_resources` |
|---|---|
| `cp`, `env`, `aws_region`, AZ letters | same |
| `vpc_cidr_inspection`, `vpc_cidr_management`, `vpc_cidr_east`, `vpc_cidr_west` | same |
| `access_internet_mode = "nat_gw"` | `create_nat_gateway_subnets = true` (`"eip"` with `false`) |
| `enable_dedicated_management_eni` | `create_management_subnet_in_inspection_vpc` |
| `enable_dedicated_management_vpc` | `enable_build_management_vpc` |
| `enable_dedicated_management_nat_gateway` | same |
| `attach_to_tgw_name` | `"<cp>-<env>-tgw"` |
| `enable_distributed_egress` | `enable_build_distributed_egress_vpcs` |

### FortiGate

| Variable | Description |
|---|---|
| `fortios_version` | `X.Y.Z`, 7.6.8 or later (7.6), or 8.0.2 or later. Not later than FortiManager |
| `fgt_instance_type` | Same CPU count as the FortiFlex configuration |
| `fortigate_admin_password` | `admin` password set by the bootstrap |
| `keypair` | EC2 key pair |
| `vpc_cidr_sg` | Admin source CIDRs for the dedicated management port |
| `firewall_policy_mode` | `1-arm` or `2-arm` |
| `asg_min_size`, `asg_max_size`, `asg_desired_size` | Initial instance count (default 1) |
| `asg_health_check_grace_period` | Default 1200 seconds: covers onboarding, license reboot and CLI template install |

### FortiManager

| Variable | Description |
|---|---|
| `fortimanager_ip` | FortiManager address the FortiGates register to (Elastic IP or fixed private IP) |
| `fortimanager_sn` | FortiManager serial number |
| `fortimanager_api_key` | API key of the REST API administrator in the auto-onboarding rule |
| `ums_autoscale_psksecret` | Pre-shared secret of `config system auto-scale` |
| `ums_hb_interval` | Auto-scale heartbeat interval, default 10 seconds |
| `fortimanager_vrf_select` | VRF to reach FortiManager. Leave unset |

`fortimanager_api_key`, `ums_autoscale_psksecret` and `fortigate_admin_password` are sensitive. Keep `terraform.tfvars` out of Git (it is in `.gitignore`), or pass them as environment variables:

```bash
export TF_VAR_fortimanager_api_key='...'
export TF_VAR_ums_autoscale_psksecret='...'
export TF_VAR_fortigate_admin_password='...'
```

## Deploy

```bash
terraform init
terraform plan -out tfplan_ums
terraform apply tfplan_ums
```

```bash
terraform output
```

| Output | Use |
|---|---|
| `autoscale_group_name` | The Auto Scaling group FortiManager scales (shown in the UMS group) |
| `gwlb_ips` | GWLB address per AZ, the `remote-ip` of `geneve-az1`, `geneve-az2`, ... |
| `fortimanager_cli_template_file` | CLI template to import into FortiManager |
| `fortimanager_policy_reference_file` | Firewall policies for the policy package |
| `fortigate_ami_id` | AMI of the launch template |

## Watch the first FortiGate

1. **EC2** > **Auto Scaling groups** > `<asg_module_prefix>-fgt_ums_asg` > **Activity**: the instance launches.
2. **CloudWatch** > **Log groups** > the module's Lambda function: the launch event attaches the network interfaces and completes the lifecycle hook.
3. **FortiManager** > **Device Manager** > **Device & Groups**: the FortiGate appears, is authorized by the auto-onboarding rule, and receives its FortiFlex license (one reboot).

Then apply the configuration of the group: [Apply Configuration](../5_3_apply_configuration/). Until FortiManager installs the CLI template, the FortiGate has no GENEVE tunnels and fails the GWLB health check, so it receives no traffic. If the grace period ends first, the Auto Scaling group replaces it.
