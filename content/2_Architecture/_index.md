---
title: "Architecture"
menuTitle: "Architecture"
weight: 20
---

## Components

| Component | Built by | Role |
|---|---|---|
| Inspection VPC (public, GWLB endpoint, private, optional NAT Gateway and management subnets) | `existing_vpc_resources` | Holds the FortiGates and the Gateway Load Balancer |
| Gateway Load Balancer, target group, listener, endpoint service | `ums_template` (Fortinet module) | Sends traffic to the FortiGates over GENEVE (UDP 6081) |
| GWLB endpoints (inspection VPC and distributed egress VPCs) | `ums_template` (Fortinet module) | Entry points that route tables point to |
| FortiGate Auto Scaling group, launch template | `ums_template` (Fortinet module) | The UMS group. FortiManager sets its instance count |
| Lambda function, EventBridge rules, DynamoDB table | `ums_template` (Fortinet module) | Instance lifecycle: builds the extra network interfaces, tracks the instances |
| Transit Gateway, east and west spoke VPCs | `existing_vpc_resources` | Centralized egress and east-west traffic |
| Distributed egress VPCs | `existing_vpc_resources` | Distributed egress traffic |
| Management VPC, FortiManager (optional FortiAnalyzer, jump box) | `existing_vpc_resources` | UMS control plane |

`ums_template` finds the resources of `existing_vpc_resources` by their `Fortinet-Role` tags, built from `cp` and `env` (for example `acme-test-inspection-vpc`). Any VPC with the same tags works, so `ums_template` also deploys into an inspection VPC that a customer built.

## Traffic flows

### Centralized egress and east-west (Transit Gateway)

1. A spoke VPC sends `0.0.0.0/0` to the Transit Gateway.
2. The Transit Gateway sends it to the inspection VPC attachment (appliance mode on, so both directions use the same AZ).
3. The attachment subnet routes to the **GWLB endpoint** of its AZ.
4. The Gateway Load Balancer encapsulates the packet in GENEVE and sends it to a healthy FortiGate. The FortiGate receives it on tunnel `geneve-az1` (`geneve-az2`, `geneve-az3`).
5. The FortiGate inspects it:
   - **Internet-bound**: the firewall policy `private_to_internet` (source `private-zone`, NAT on) sends it out the internet-facing port, through the NAT Gateway or the instance Elastic IP (`access_internet_mode`).
   - **East-west**: a policy route sends it back into the same GENEVE tunnel, and the GWLB endpoint returns it to the Transit Gateway, which delivers it to the destination spoke.

### Distributed egress (GWLB endpoint in the workload VPC)

1. The workload subnet of a distributed VPC sends `0.0.0.0/0` to the **GWLB endpoint in that VPC**.
2. The Gateway Load Balancer sends the packet to a FortiGate over GENEVE, as above.
3. The FortiGate inspects it and returns it through the same tunnel (policy route on the distributed VPC CIDRs).
4. The GWLB endpoint delivers it to the VPC's own Internet Gateway. Return traffic comes back in through the Internet Gateway's ingress route table, which points to the GWLB endpoint.

Both paths share one Gateway Load Balancer endpoint service and the same FortiGates. The FortiGates tell the paths apart by source and destination CIDR (`spoke_cidrs` for centralized, the distributed VPC CIDRs for distributed), so these CIDRs must not overlap.

## How UMS works on AWS

| Step | From | To | Action |
|---|---|---|---|
| 1 | FortiManager admin | FortiManager | Sets the **Auto-Scale Instance Count** of the UMS group |
| 2 | FortiManager | AWS Auto Scaling group | The AWS SDN connector sets min, max and desired capacity |
| 3 | Auto Scaling group | New FortiGate | Launches it from the launch template (bootstrap configuration) |
| 4 | FortiGate | FortiManager | `execute central-mgmt register-device-by-ip` with the API key, over FGFM (TCP 541) |
| 5 | FortiManager | FortiManager | The auto-onboarding rule authorizes it into the ADOM and device group |
| 6 | FortiManager | FortiFlex | The FortiFlex connector creates or reactivates an entitlement |
| 7 | FortiManager | FortiGate | Installs the FortiFlex license (the FortiGate reboots) |
| 8 | FortiManager | FortiGate | Installs the CLI template and the policy package |
| 9 | Gateway Load Balancer | FortiGate | The health check (probe-response) passes and traffic starts |

### Bootstrap

With UMS on, the Fortinet module writes this into each FortiGate's bootstrap configuration (user data), from the `fortimanager_*` and `ums_*` variables of `ums_template`:

```
config system central-management
    set type fortimanager
    set fmg "<fortimanager_ip>"
    set serial-number "<fortimanager_sn>"
end
config system auto-scale
    set status enable
    set sync-interface "<internet-facing port>"
    set hb-interval <ums_hb_interval>
    set callback-url "<fortimanager_ip>"
    set cloud-mode ums
    set role primary
    set psksecret "<ums_autoscale_psksecret>"
end
execute central-mgmt register-device-by-ip <fortimanager_ip> <fortimanager_api_key>
```

The `register-device-by-ip` command runs **once, at first boot**. FortiManager must be configured and reachable before `ums_template` launches the FortiGates.

### Division of work

| Task | Done by |
|---|---|
| Network interfaces (including the dedicated management port), GWLB target registration | AWS Auto Scaling group and the module's Lambda function |
| Admin password | Bootstrap (`fortigate_admin_password`) |
| Registration to FortiManager | Bootstrap |
| License | FortiManager, FortiFlex connector, auto-onboarding rule |
| GENEVE tunnels, probe-response, routes, policy routes | FortiManager CLI template (`fortimanager/fmg-cli-template.txt`, rendered by `ums_template`) |
| Firewall policies | FortiManager policy package |
| Instance count | FortiManager (Auto-Scale Instance Count) |

In UMS mode the module's Lambda function does not install a license or push configuration. This is why `ums_template` renders the GENEVE configuration as a FortiManager CLI template with this deployment's GWLB addresses.

### Health check

The Gateway Load Balancer checks `http://<FortiGate>:8008/` (`gwlb_health_check_port`), answered by `config system probe-response`. The CLI template configures probe-response, so a FortiGate passes the health check, and receives traffic, only after FortiManager has configured it. `asg_health_check_grace_period` (default 1200 seconds) must cover boot, onboarding, the license reboot and the CLI template install.

## Firewall interface modes

| `firewall_policy_mode` | GENEVE (GWLB) port | Internet-facing port | Dedicated management port |
|---|---|---|---|
| `1-arm` | port1 | port1 | port2 |
| `2-arm` | port1 | port2 | port3 |

The dedicated management port exists when `enable_dedicated_management_vpc` (port in the management VPC) or `enable_dedicated_management_eni` (port in management subnets of the inspection VPC) is `true`. The CLI template gives it routes to `vpc_cidr_management` and the admin CIDRs in `vpc_cidr_sg`; the internet-facing port keeps the default route.

## FortiManager reachability

The FortiGates must reach `fortimanager_ip` on TCP 541 when they first boot.

| Model | `fortimanager_ip` | FortiManager security group |
|---|---|---|
| **Internet** (default lab) | FortiManager Elastic IP (`fortimanager_public_ip` output) | `fgfm_additional_source_cidrs` must allow the FortiGates' public egress addresses (NAT Gateway or instance Elastic IPs). The lab default is `["0.0.0.0/0"]`; FortiManager accepts only devices that present the API key |
| **Private** | FortiManager private IP (`fortimanager_private_ip` output) | The inspection and management VPC CIDRs are always allowed |

In the private model, the internet-facing port of the FortiGate holds the default route at boot. The FortiGate reaches FortiManager's private IP only if that path routes there: a Transit Gateway route from the inspection VPC to the management VPC, or a FortiManager in the same subnet as the dedicated management port. Test the path before you rely on it.
