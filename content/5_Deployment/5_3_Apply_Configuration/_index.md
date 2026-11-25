---
title: "Apply Configuration"
menuTitle: "Apply Configuration"
weight: 53
---

FortiManager configures every member of the UMS group with the same CLI template and policy package. `ums_template` renders both from `fortimanager_templates/` with the addresses of this deployment.

## The CLI template

`fortimanager/fmg-cli-template.txt` contains:

| Section | Content |
|---|---|
| `config system probe-response` | HTTP probe on `gwlb_health_check_port` (8008) for the GWLB health check |
| `config system interface` | `allowaccess` and default gateway of the GENEVE, internet-facing and dedicated management ports |
| `config system geneve` | One tunnel per AZ: `geneve-az1`, `geneve-az2` (, `geneve-az3`), `remote-ip` = the GWLB address in that AZ, `type ppp` |
| `config system zone` | `private-zone` with all GENEVE tunnels |
| `config router static` | `/32` routes to the GWLB addresses through the GENEVE port; routes for `spoke_cidrs` (and distributed CIDRs) through the tunnels; routes for the management VPC and admin CIDRs through the dedicated management port |
| `config router policy` | Return traffic into the tunnel it arrived on. With distributed egress: separate rules for distributed traffic and for centralized east-west traffic, so centralized internet egress uses the default route |
| `config system global`, `config system fortiguard` | GUI upgrade warnings off, automatic firmware upgrade off (FortiManager controls firmware) |

Every member gets all GENEVE tunnels, whatever its own AZ, so one template fits the whole group. The GWLB sends a FortiGate traffic only through the tunnel of its own AZ, unless `allow_cross_zone_load_balancing` is `true`.

{{% notice note %}}
The GWLB addresses change only when the Gateway Load Balancer is replaced. After any `terraform apply` that replaces it, re-import the CLI template.
{{% /notice %}}

## Create the CLI template in FortiManager

1. **Device Manager** > **Provisioning Templates** > **CLI Templates** > **Create New** > **CLI Template**.
2. **Name**: for example `ums-geneve`. **Type**: CLI Script.
3. Paste the content of `fortimanager/fmg-cli-template.txt`.
4. **OK**.
5. Create a **CLI Template Group** (for example `ums-group`) with `ums-geneve` as a member, and assign it to the UMS device group.

## Create the policy package

1. **Policy & Objects** > **Policy Packages** > **Create New** > **New Package**, for example `ums-policy`.
2. Create the normalized interfaces (**Policy & Objects** > **Object Configurations** > **Normalized Interface**) for `private-zone` and the internet-facing port, mapped per device to the zone and port of the same names.
3. Add the two policies of `fortimanager/fmg-policy-reference.txt`:

   | Name | From | To | Source | Destination | Service | Action | NAT |
   |---|---|---|---|---|---|---|---|
   | `private_to_internet` | `private-zone` | internet-facing port (port1 in `1-arm`, port2 in `2-arm`) | all | all | ALL | Accept | On |
   | `private_to_private` | `private-zone` | `private-zone` | all | all | ALL | Accept | Off |

4. Add security profiles to the policies as needed (FortiFlex service package permitting).
5. Assign the policy package to the UMS device group (**Installation Targets**).

## Link them to the auto-onboarding rule

Edit the auto-onboarding rule (**Device Manager** > **Device & Groups** > **Add Device** > **Auto Onboarding** > **Onboarding Rule**) and set **Install Configuration** to **Manual Configuration** with the template group `ums-group` and the policy package `ums-policy`. Every FortiGate that the group adds from now on receives them when it is onboarded.

## Install on the members onboarded so far

1. **Device Manager** > **Device & Groups** > select the UMS group members.
2. **Install Wizard** > **Install Device Settings and Policy Package** > select `ums-policy` > **Next** > preview > **Install**.

## Verify

On a FortiGate:

```
get system interface | grep geneve
diagnose sys geneve list
get router info routing-table all
diagnose sniffer packet any 'udp port 6081' 4 5
```

In AWS: **EC2** > **Target groups** > the module's GENEVE target group: the FortiGate turns **healthy** after `gwlb_healthy_threshold` successful checks (default 5 x 60 seconds).

Traffic test from a spoke or distributed egress Linux instance (through the jump box):

```bash
curl -s ifconfig.me    # centralized egress: the NAT Gateway address of the inspection VPC
```

Then **FortiView** or **Log & Report** > **Forward Traffic** on the FortiGate, or in FortiManager / FortiAnalyzer, shows the sessions.
