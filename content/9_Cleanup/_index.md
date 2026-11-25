---
title: "Cleanup"
menuTitle: "Cleanup"
weight: 90
---

Destroy in the reverse order of deployment: the UMS group first, then the lab.

## 1. FortiManager and FortiFlex

1. In FortiManager, delete the UMS group members from **Device Manager** > **Device & Groups**, and the UMS connector if FortiManager stays in use.
2. In FortiFlex, stop the entitlements of the FortiGates, so they consume no points.

## 2. ums_template

```bash
cd terraform/ums_template
terraform destroy
```

This terminates the FortiGates and deletes the Gateway Load Balancer, the GWLB endpoints, the routes to them, the Lambda function, the DynamoDB table and the rendered `fortimanager/` files.

{{% notice note %}}
If FortiManager changed the instance count since the last apply, `terraform destroy` still removes the Auto Scaling group and all its instances.
{{% /notice %}}

## 3. existing_vpc_resources

```bash
cd ../existing_vpc_resources
terraform destroy
```

This deletes FortiManager (and its configuration), the management, inspection, spoke and distributed egress VPCs, and the Transit Gateway.

## Check for leftovers

```bash
aws ec2 describe-instances --filters "Name=tag:Prefix,Values=<cp>" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId'
aws ec2 describe-addresses --filters "Name=tag:Prefix,Values=<cp>"
```

Both return empty lists when the cleanup is complete.
