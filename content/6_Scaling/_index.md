---
title: "Scaling"
menuTitle: "Scaling"
weight: 60
---

In UMS, the FortiManager administrator sets the instance count. FortiManager's AWS SDN connector writes it to the Auto Scaling group (`<asg_module_prefix>-fgt_ums_asg`); AWS launches or terminates instances; FortiManager onboards, licenses and configures the new ones.

## Scale out

Prerequisite: the first FortiGate of the group is authorized in FortiManager, and the CLI template and policy package are linked to the auto-onboarding rule ([Apply Configuration](../5_deployment/5_3_apply_configuration/)).

1. **Device Manager** > **Device & Groups**.
2. Right-click the UMS device group > **Auto-Scale Instance Count**.
3. Set the minimum, maximum and desired counts to the **same** new number, for example `2`.
4. **OK**.

Each new FortiGate then:

1. launches from the launch template and runs its bootstrap configuration,
2. registers to FortiManager with the API key,
3. is onboarded by the auto-onboarding rule (ADOM, device group),
4. receives a FortiFlex license (one reboot),
5. receives the CLI template and policy package,
6. passes the GWLB health check and starts receiving traffic.

Allow 15 to 25 minutes per scale-out. Each new FortiGate uses a FortiFlex entitlement (points per day) while it runs.

## Scale in

1. **Device Manager** > **Device & Groups** > right-click the UMS group > **Auto-Scale Instance Count**.
2. Set the three counts to the same, lower number, for example `1`.
3. **OK**. AWS terminates instances (the GWLB target group drains each for 30 seconds first).
4. **Clean up FortiManager manually.** FortiManager does not delete the terminated FortiGate. In **Device Manager** > **Device & Groups**, delete the device that no longer exists (it shows as down / connection lost).
5. In FortiFlex, check that the entitlement of the terminated FortiGate is stopped, so it uses no points. Stop it in the FortiFlex portal if it is still active.

{{% notice warning %}}
The AWS Auto Scaling group picks which instance to terminate. With `NewestInstance` or the default policy, any member can go. Plan capacity so that the remaining FortiGates carry the traffic.
{{% /notice %}}

## Terraform and the instance count

`asg_min_size`, `asg_max_size` and `asg_desired_size` are only the size at deployment. After FortiManager has changed the count, a `terraform apply` of `ums_template` with the old values sets the Auto Scaling group back to them. Before you run `terraform apply` again:

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names asg-fgt_ums_asg \
  --query 'AutoScalingGroups[0].[MinSize,MaxSize,DesiredCapacity]'
```

and set the three variables in `terraform.tfvars` to these values.

## Capacity guidance

| Item | Guidance |
|---|---|
| Minimum | 1 per AZ in production, so each AZ keeps a FortiGate (with `allow_cross_zone_load_balancing = false` an AZ without a healthy FortiGate drops traffic) |
| Cross-zone load balancing | `allow_cross_zone_load_balancing = true` lets the GWLB use FortiGates in other AZs when an AZ has none healthy, at inter-AZ data cost |
| Instance type | One type per group (`fgt_instance_type`); changing it replaces the launch template and needs a FortiFlex configuration with the matching CPU count |
