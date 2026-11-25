---
title: "Upgrades"
menuTitle: "Upgrades"
weight: 80
---

A FortiOS upgrade of the UMS group has two parts: the **running members**, upgraded by FortiManager, and the **launch template**, so that new members launch on the new version. FortiManager is upgraded first.

{{% notice info %}}
Fortinet's UMS guides do not describe a UMS-specific firmware procedure. This page uses FortiManager's standard device firmware upgrade and the launch template of the Auto Scaling group. Test it on a lab group first.
{{% /notice %}}

## Rules

- FortiManager must run the **same or a later** version than the FortiGates. Upgrade FortiManager first.
- Stay at or above the UMS minimums: FortiOS 7.6.8 (7.6) or 8.0.2.
- Follow the FortiOS **upgrade path** ([upgrade path tool](https://docs.fortinet.com/upgrade-tool)) from the running version to the target.
- FortiManager needs a valid firmware contract to upgrade FortiGates.
- Back up first: FortiManager (**System Settings** > **Dashboard** > **System Information** > **Backup**) and a revision of each FortiGate's configuration (FortiManager keeps them in **Revision History**).

## 1. Upgrade FortiManager

Follow the FortiManager upgrade guide for the target release. In the lab, FortiManager is the instance built by `existing_vpc_resources`: upgrade it from **System Settings** > **Dashboard** > **Firmware Version** > **Upgrade Firmware**. Keep `fortimanager_os_version` in `existing_vpc_resources` at the version it runs, so the documentation of the deployment stays correct (the variable only selects the AMI at creation).

Check afterwards that the UMS group, the SDN connector and the FortiFlex connector still work: the group shows its instance counts, and the devices are connected.

## 2. Upgrade the running FortiGates

1. **Device Manager** > **Device & Groups** > select the UMS group (or its members).
2. **Firmware** (or **Firmware Templates** > create a template with the target version and assign it to the group).
3. Select the target version and schedule the upgrade.

Upgrade the members one at a time, or a part of them at a time, so the rest carry the traffic. A FortiGate fails the GWLB health check while it reboots, and the GWLB sends new flows to the others. The Auto Scaling group uses the GWLB health check, so suspend its `HealthCheck` and `ReplaceUnhealthy` processes during the upgrade; otherwise it can replace a rebooting member:

```bash
aws autoscaling suspend-processes --auto-scaling-group-name asg-fgt_ums_asg \
  --scaling-processes HealthCheck ReplaceUnhealthy
# ... upgrade the members ...
aws autoscaling resume-processes --auto-scaling-group-name asg-fgt_ums_asg \
  --scaling-processes HealthCheck ReplaceUnhealthy
```

After each member, check in FortiManager that the device is connected, its firmware is the target version, and its configuration is in sync; in AWS that its target is healthy.

## 3. Update the launch template

New members must launch on the same version as the running ones. In `ums_template/terraform.tfvars`:

1. Set `fortios_version` to the target version.
2. Set `asg_min_size`, `asg_max_size` and `asg_desired_size` to the count FortiManager last set (see [Scaling](../6_scaling/#terraform-and-the-instance-count)).
3. Apply:

   ```bash
   terraform plan -out tfplan_ums
   terraform apply tfplan_ums
   terraform output fortigate_ami_id
   ```

The plan must change only the launch template (a new AMI) and the Auto Scaling group's launch template version. Running instances are not replaced.

## Upgrading by replacement

Instead of upgrading in place, the group can be refreshed with new instances: update the launch template (step 3), then scale out by the current count (new members launch on the new version and are onboarded), check them, and scale in to the original count. The Auto Scaling group picks the instances to terminate; set its termination policy to `OldestInstance` first so that the old members go. Each removed member needs the [manual FortiManager clean-up](../6_scaling/#scale-in).
