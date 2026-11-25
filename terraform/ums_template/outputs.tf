output "fortimanager_cli_template_file" {
  value       = local_file.fmg_cli_template.filename
  description = "FortiManager CLI template for the UMS group (GENEVE tunnels, health check, routes)"
}

output "fortimanager_policy_reference_file" {
  value       = local_file.fmg_policy_reference.filename
  description = "Firewall policies to create in the UMS group's FortiManager policy package"
}

output "gwlb_ips" {
  value       = zipmap(local.az_list, local.gwlb_ips)
  description = "GWLB address in each AZ (remote-ip of geneve-<az>)"
}

output "autoscale_group_name" {
  value       = "${local.module_name_prefix}fgt_ums_asg"
  description = "Name of the FortiGate Auto Scaling group that FortiManager scales"
}

data "aws_launch_template" "fgt_ums" {
  name       = "${local.module_name_prefix}fgt_ums_template"
  depends_on = [module.spk_tgw_gwlb_asg_fgt_igw]
}

output "fortigate_ami_id" {
  value       = data.aws_launch_template.fgt_ums.image_id
  description = "AMI ID used by the FortiGate UMS group"
}
