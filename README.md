
# AWS_User_Managed_Scaling

To view the workshop, please go here: [GitHub Pages Link](https://fortinetcloudcse.github.io/AWS_User_Managed_Scaling/)

---

Terraform and documentation for a **FortiGate User Managed Scaling (UMS)** group on AWS. FortiManager onboards, licenses (FortiFlex), configures and scales the FortiGates. The FortiGates sit behind an AWS Gateway Load Balancer (GENEVE) and inspect centralized egress and east-west traffic through a Transit Gateway, and distributed egress traffic through GWLB endpoints in workload VPCs.

## Repository layout

| Path | Content |
|---|---|
| `terraform/existing_vpc_resources/` | Lab: inspection VPC, management VPC with FortiManager, Transit Gateway, east/west spoke VPCs, distributed egress VPCs |
| `terraform/ums_template/` | FortiGate UMS group: Auto Scaling group, Gateway Load Balancer, GWLB endpoints, routes, FortiManager CLI template. Wraps `fortinetdev/cloud-modules/aws//examples/spk_tgw_gwlb_asg_fgt_igw` 1.1.7 with `fmg_integration.ums` |
| `content/` | Hugo site (the workshop guide) |

## Requirements

- FortiOS and FortiManager 7.6.8 or later (7.6), or 8.0.2 or later; FortiManager at the same or a later version than the FortiGates
- FortiFlex program with a FortiGate-VM configuration
- Terraform 1.5 or later, AWS credentials

## Quick start

```bash
cd terraform/existing_vpc_resources
cp terraform.tfvars.example terraform.tfvars   # edit
terraform init && terraform apply
```

Configure FortiFlex and FortiManager (API admin, AWS SDN connector, UMS connector, FortiFlex connector, auto-onboarding rule), then:

```bash
cd ../ums_template
cp terraform.tfvars.example terraform.tfvars   # fortimanager_ip, fortimanager_sn, fortimanager_api_key, ...
terraform init && terraform apply
```

Import `fortimanager/fmg-cli-template.txt` into FortiManager as a CLI template for the UMS group, create the policy package, and scale from FortiManager (**Auto-Scale Instance Count**).

## Build the site locally

```bash
docker run --rm -v "$PWD:/home/UserRepo" public.ecr.aws/k4n6m5h8/fortinet-hugo:latest build
```

---

For more information on creating these workshops, visit [FortinetCloudCSE User Repo](https://fortinetcloudcse.github.io/UserRepo/)
