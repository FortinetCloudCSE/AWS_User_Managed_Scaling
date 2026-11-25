#
# FortiManager CLI template for the UMS group
#
# In UMS mode the module's Lambda function pushes no configuration, so the GENEVE tunnels to the
# GWLB, the probe-response health check, the routes and the policy routes are installed by
# FortiManager. This file renders them, with the GWLB addresses of this deployment, into
#   fortimanager/fmg-cli-template.txt     -> FortiManager CLI template, assigned to the UMS group
#   fortimanager/fmg-policy-reference.txt -> the firewall policies for the policy package
# Every FortiGate gets one GENEVE tunnel per AZ (geneve-az1, geneve-az2, ...), whatever its own
# AZ, so a single CLI template fits every member of the group.
#

locals {
  module_name_prefix = var.asg_module_prefix == "" ? "" : "${var.asg_module_prefix}-"
  gwlb_name          = "${local.module_name_prefix}gwlb-fgt"

  # Interface names. 1-arm: port1 carries GENEVE and internet traffic. 2-arm: port1 carries
  # GENEVE, port2 internet. The dedicated management port follows them.
  fgt_geneve_port = "port1"
  fgt_public_port = var.firewall_policy_mode == "2-arm" ? "port2" : "port1"
  fgt_mgmt_port   = (var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni) ? "port${local.management_device_index + 1}" : ""

  # The dedicated management port has no default route (the internet-facing port keeps it):
  # it gets routes to the management VPC and to the admin CIDRs (vpc_cidr_sg) instead.
  mgmt_route_cidrs = local.fgt_mgmt_port == "" ? [] : distinct(concat(
    [var.vpc_cidr_management],
    [for c in var.vpc_cidr_sg : c if c != "0.0.0.0/0"]
  ))

  # Subnets of the GWLB (the FortiGate GENEVE side), one per AZ in az_list order.
  gwlb_subnet_ids = concat(
    var.firewall_policy_mode == "1-arm"
    ? [data.aws_subnet.inspection_public_az1.id, data.aws_subnet.inspection_public_az2.id]
    : [data.aws_subnet.inspection_private_az1.id, data.aws_subnet.inspection_private_az2.id],
    var.availability_zone_3 == "" ? [] : (
      var.firewall_policy_mode == "1-arm"
      ? [data.aws_subnet.inspection_public_az3[0].id]
      : [data.aws_subnet.inspection_private_az3[0].id]
    )
  )
}

data "aws_lb" "gwlb" {
  name       = local.gwlb_name
  depends_on = [module.spk_tgw_gwlb_asg_fgt_igw]
}

data "aws_network_interface" "gwlb" {
  count = length(local.gwlb_subnet_ids)
  filter {
    name   = "description"
    values = ["ELB gwy/${data.aws_lb.gwlb.name}/*"]
  }
  filter {
    name   = "interface-type"
    values = ["gateway_load_balancer"]
  }
  filter {
    name   = "subnet-id"
    values = [local.gwlb_subnet_ids[count.index]]
  }
}

locals {
  gwlb_ips = [for eni in data.aws_network_interface.gwlb : eni.private_ip]

  fmg_cli_template = templatefile("${path.module}/fortimanager_templates/fmg-cli-template.tftpl", {
    az_list                   = local.az_list
    gwlb_ips                  = local.gwlb_ips
    geneve_port               = local.fgt_geneve_port
    public_port               = local.fgt_public_port
    mgmt_port                 = local.fgt_mgmt_port
    mgmt_route_cidrs          = local.mgmt_route_cidrs
    health_check_port         = var.gwlb_health_check_port
    spoke_cidrs               = local.spoke_cidrs
    centralized_spoke_cidrs   = local.centralized_spoke_cidrs
    distributed_egress_cidrs  = local.distributed_egress_cidrs
    enable_distributed_egress = var.enable_distributed_egress
  })
  fmg_policy_reference = templatefile("${path.module}/fortimanager_templates/fmg-policy-reference.tftpl", {
    public_port = local.fgt_public_port
  })
}

resource "local_file" "fmg_cli_template" {
  filename        = "${path.module}/fortimanager/fmg-cli-template.txt"
  content         = local.fmg_cli_template
  file_permission = "0644"
}

resource "local_file" "fmg_policy_reference" {
  filename        = "${path.module}/fortimanager/fmg-policy-reference.txt"
  content         = local.fmg_policy_reference
  file_permission = "0644"
}
