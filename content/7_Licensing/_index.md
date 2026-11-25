---
title: "Licensing with FortiFlex"
menuTitle: "Licensing"
weight: 70
---

The UMS group uses **FortiFlex only**. FortiManager licenses each FortiGate; the Terraform templates hold no FortiFlex credentials, serial numbers or tokens.

## How a FortiGate gets its license

1. The FortiGate boots from the **BYOL** FortiGate AMI (FortiFlex runs on the BYOL image), unlicensed.
2. It registers to FortiManager. The auto-onboarding rule's **Install License** action is **Flex VM**.
3. FortiManager's **FortiFlex connector** creates or reactivates a FortiFlex VM entitlement in the program, with the connector's default **configuration**, and installs the token on the FortiGate.
4. The FortiGate validates the license with FortiGuard and reboots.
5. FortiManager installs the configuration of the group.

## What to plan

| Item | Detail |
|---|---|
| FortiFlex configuration | FortiGate Virtual Machine, CPU count = vCPUs of `fgt_instance_type`, service package as needed |
| Points | Each running FortiGate consumes points per day for its configuration. Size the program balance for the maximum instance count |
| API user | FortiCloud IAM API user with a permission profile: FortiFlex portal, Access on, Admin |
| FortiGuard reachability | The FortiGates need internet access (NAT Gateway or Elastic IP) to validate the license |

## Scale-in and entitlements

When the group scales in, the terminated FortiGate's entitlement must not keep consuming points. After a scale-in, check the entitlement list in the FortiFlex portal (or FortiManager's FortiFlex connector view) and stop the entitlements of terminated FortiGates. A later scale-out can reuse stopped entitlements of the same configuration.

## Changing the configuration

To change the service package or CPU count:

1. Create or edit the FortiFlex configuration.
2. Select it as the default configuration of the FortiFlex connector in FortiManager.
3. If the CPU count changes, change `fgt_instance_type` in `ums_template` to match and `terraform apply` (the launch template changes; running FortiGates keep their instance type until they are replaced).

New FortiGates receive the new configuration. Running FortiGates keep their entitlement until it is changed in FortiFlex.
