# CLAUDE.md — AWS_User_Managed_Scaling

> Global preferences: `~/.claude/CLAUDE.md`
> Sister repo (reference only, never add UMS material to it): `FortinetCloudCSE/Autoscale-Simplified-Template`, the CloudWatch-driven autoscale version of the same architecture.

## Project in One Line

Terraform and a Hugo guide for a **FortiGate User Managed Scaling (UMS)** group on AWS. FortiManager onboards, licenses (FortiFlex), configures and scales the FortiGates. The FortiGates sit behind a Gateway Load Balancer (GENEVE) and handle centralized egress and east-west traffic through a Transit Gateway, plus distributed egress through GWLB endpoints in workload VPCs.

## Fixed decisions

- **FortiFlex only.** No BYOL license files, no PAYG/on-demand group. FortiManager's FortiFlex connector licenses the FortiGates, so the templates hold no FortiFlex credentials. The module runs with `license_type = "byol"` because FortiFlex uses the BYOL AMI.
- **FortiManager is required**, and it drives scaling. There are no CloudWatch alarms or scaling policies.
- **Minimum versions:** FortiOS and FortiManager 7.6.8 (7.6 branch) or 8.0.2. `fortios_version` has a validation for this. FortiManager must run the same or a later version than the FortiGates.
- **One module call, one Auto Scaling group** (`<asg_module_prefix>-fgt_ums_asg`). There are no blue-green slots and no upgrade toolset; don't add them unless asked.

## Layout

```
terraform/existing_vpc_resources/  — lab: inspection VPC, management VPC + FortiManager, TGW, east/west spokes, distributed egress VPCs
terraform/ums_template/            — UMS group: fortinetdev/cloud-modules/aws//examples/spk_tgw_gwlb_asg_fgt_igw 1.1.7 with fmg_integration.ums
  ums_group.tf                     — module call, fmg_integration, dedicated management port
  fortimanager.tf                  — looks up GWLB ENI IPs, renders fortimanager/fmg-cli-template.txt + fmg-policy-reference.txt
  fortimanager_templates/*.tftpl   — the CLI template and policy reference sources
  vpc_inspection.tf, vpc_distributed_egress.tf — Fortinet-Role tag discovery and route changes
content/                           — Hugo guide, one chapter per directory (_index.md, ordered by weight)
scripts/repoConfig.json            — site chrome (title, author, theme variant, shortcuts)
```

Each template has `terraform.tfvars.example` and `tfvars.ui` (the same variables with `@ui-*` annotations). **Keep all three in sync:** `variables.tf`, `terraform.tfvars.example`, `tfvars.ui`. Every uncommented key in the two tfvars files must be a declared variable.

## How UMS works here (the non-obvious part)

- With `fmg_integration.ums` set, module 1.1.7 forces `fgt_lic_mgmt = "fmg"`. Its Lambda then **skips `gen_config_content` entirely**: no GENEVE tunnels, no `/32` routes to the GWLB, no probe-response, no auto-scale role, no `user_conf_content`. The Lambda only attaches the ENIs and tracks the instances in DynamoDB. FortiManager installs everything else, which is why `ums_template` renders the CLI template with this deployment's GWLB addresses. (Source: `modules/fortigate/fgt_asg/fgt-asg-lambda.py` `do_launch`, under `.terraform/modules/` after `terraform init`.)
- The bootstrap (`modules/fortigate/fgt_asg/fgt-userdata.tftpl`) writes `central-management`, `auto-scale` with `set cloud-mode ums` and `callback-url`, and runs `execute central-mgmt register-device-by-ip <fortimanager_ip> <fortimanager_api_key>` **once, at first boot**. FortiManager must be configured and reachable on TCP 541 before `ums_template` launches the FortiGates.
- The module fixes the ASG health check type to ELB. A FortiGate passes the GWLB health check only after FortiManager has installed probe-response, so `asg_health_check_grace_period` defaults to 1200.
- Every FortiGate gets one GENEVE tunnel per AZ (`geneve-az1`...), so a single CLI template fits the whole group.
- The dedicated management port has no VRF: `vrf-select` in the bootstrap would deadlock, because the port isn't in the VRF at boot. The CLI template gives the port `defaultgw disable` plus routes to `vpc_cidr_management` and to the non-`0.0.0.0/0` entries of `vpc_cidr_sg`.
- FortiManager reachability defaults to its Elastic IP, with `fgfm_additional_source_cidrs = ["0.0.0.0/0"]` in the lab. The bootstrap can't add routes for a private path.
- After FortiManager changes the instance count, a `terraform apply` with the old `asg_min_size`/`asg_max_size`/`asg_desired_size` sets the Auto Scaling group back to them. The docs tell users to copy the current counts into tfvars first.

## Build and check

```bash
# Terraform (no AWS calls)
cd terraform/ums_template && terraform init -backend=false && terraform validate
cd terraform/existing_vpc_resources && terraform init -backend=false && terraform validate
terraform fmt -recursive terraform

# Render the CLI template with sample values
echo 'templatefile("fortimanager_templates/fmg-cli-template.tftpl", {az_list=["az1","az2"], gwlb_ips=["10.0.2.10","10.0.3.20"], geneve_port="port1", public_port="port2", mgmt_port="port3", mgmt_route_cidrs=["10.3.0.0/16"], health_check_port=8008, spoke_cidrs=["192.168.0.0/24"], centralized_spoke_cidrs=["192.168.0.0/24"], distributed_egress_cidrs=[], enable_distributed_egress=false})' | terraform console

# Hugo site, the same way CI builds it
docker run --rm -v "$PWD:/home/UserRepo" public.ecr.aws/k4n6m5h8/fortinet-hugo:latest build
```

There is no test suite and nothing has a plan run against AWS in CI. `npm install && hugo serve` does **not** work: Hugo's config lives in CentralRepo, and the `hugo` script in `package.json` references a `config.toml` and `docs/` that don't exist.

## Writing rules

- **Docs describe how it works and how to run it.** No history, no "previously" or "used to" wording, and no references to the autoscale template's past behavior.
- **Use exact variable, output and resource names** (`fortimanager_api_key`, not "the API key variable").
- Use the `{{% notice info|note|warning %}}` shortcodes. Don't use mermaid: the theme build doesn't load the mermaid library, so a mermaid block renders as raw text. Use a table or a numbered list instead.
- Mark anything not tested on a live FortiManager/FortiGate as unverified, rather than stating it as fact.

## Working rules

- Commit or push only when asked. Work on a `dev/*` branch and open a PR into `main`.
- Never log in to the user's FortiGates or FortiManager with passwords.
- Never commit `terraform.tfvars`, state, `*.lic`, `.terraform/`, or `terraform/ums_template/fortimanager/` (the rendered files contain deployment addresses). `.gitignore` covers all of these.

## Gotchas

- **`docs/` is machine-owned — never put anything there.** CentralRepo's `batch_repo_update.py` deletes it on `main`.
- **`.github/workflows/static.yml` is template-managed.** CentralRepo's batch update overwrites it, so hand-edits are lost. The same run also manages `layouts/shortcodes/FTNThugoFlow.html`, `docker-compose.yml`, `hugo.toml`, `config.toml` and `scripts/docker_*.sh`.
- **Change site chrome in `scripts/repoConfig.json`**, never in content.
- **Repo-local `layouts/` wins over the container's.** Never land a copy of a CentralRepo shortcode here; the two drift.
- **Built page URLs** for these chapter bundles are directories (`2_architecture/index.html`), so relative links like `../2_architecture/#fortimanager-reachability` resolve.
- **`package.json`/`package-lock.json` are in `.gitignore` but tracked.** An ignore rule is not evidence that a file is untracked.
- `.repo_upgrade_version`, `repo_upgrade_spec.json` and `migration_log*.csv` are CentralRepo migration bookkeeping. The CSVs describe the UserRepo template, not this repo; never treat them as input.
- `scripts/{gen_handouts,lint_paths}.py` and `.github/workflows/{path-lint,handout-pdf}.yml` stay inert until `deploymentPaths` is declared.
- **Jenkins and new PRs.** Jenkins only gets `push` webhooks, and its multibranch job skips branches that already have an open PR. So a PR opened immediately after a branch's first push may never get a `ci/jenkins/build-status` check. If that check is required, the merge stays blocked.
- **Merge settings:** squash, merge commit and rebase are all enabled. No branch protection was readable from a non-admin token.
- `terraform/existing_vpc_resources/verify_scripts/` came from the autoscale repo. It still reads the removed `enable_autoscale_deployment` and `enable_ha_pair_deployment` variables; they come back empty, which is harmless.
