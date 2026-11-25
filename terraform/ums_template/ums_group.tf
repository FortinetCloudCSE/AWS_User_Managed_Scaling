locals {
  dedicated_mgmt = var.enable_dedicated_management_vpc ? "-wdm" : var.enable_dedicated_management_eni ? "-wdm-eni" : ""
}
locals {
  az_list = var.availability_zone_3 != "" ? ["az1", "az2", "az3"] : ["az1", "az2"]
}
locals {
  # All spoke CIDRs south of the TGW that need a FortiGate east-west inspection
  # route. Defaults to the demo east/west VPCs; override var.spoke_cidrs with
  # the real production spoke list if it differs. Distributed egress VPC CIDRs
  # (see vpc_distributed_egress.tf) are always appended when enabled,
  # since they route through the same shared geneve tunnels but aren't part of
  # the TGW-attached spoke list.
  spoke_cidrs = distinct(concat(
    length(var.spoke_cidrs) > 0 ? var.spoke_cidrs : [var.vpc_cidr_east, var.vpc_cidr_west],
    local.distributed_egress_cidrs,
  ))
}
locals {
  # The east/west-only subset of spoke_cidrs, kept separate from the merged list above.
  # Distributed egress needs this distinction for policy routing: centralized
  # east-west traffic and distributed-VPC traffic both arrive on the same shared geneve
  # tunnels, and only a src+dst-scoped policy route (using this list, not the merged one)
  # can tell them apart from centralized egress-to-internet traffic. See vpc_distributed_egress.tf
  # and the config router policy block of fortimanager_templates/fmg-cli-template.tftpl.
  centralized_spoke_cidrs = length(var.spoke_cidrs) > 0 ? var.spoke_cidrs : [var.vpc_cidr_east, var.vpc_cidr_west]
}
locals {
  management_device_index = var.firewall_policy_mode == "2-arm" ? 2 : 1
}
locals {
  # Forced off regardless of enable_fgt_management_public_ip when the management VPC egresses
  # through its dedicated NAT Gateway instead -- see var.enable_dedicated_management_nat_gateway.
  fgt_management_public_ip_effective = var.enable_fgt_management_public_ip && !var.enable_dedicated_management_nat_gateway
}
# Management VPC Fortinet-Role tags - auto-constructed from cp and env
locals {
  management_vpc = "${var.cp}-${var.env}-management-vpc"
}
locals {
  management_public_az1 = "${var.cp}-${var.env}-management-public-az1"
}
locals {
  management_public_az2 = "${var.cp}-${var.env}-management-public-az2"
}
locals {
  management_public_az3 = "${var.cp}-${var.env}-management-public-az3"
}

# Management VPC lookups (for dedicated management VPC mode)
# Uses Fortinet-Role tags for consistency with inspection VPC resource discovery
data "aws_vpc" "management_vpc" {
  count = var.enable_dedicated_management_vpc ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.management_vpc]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_subnet" "public_subnet_az1" {
  count = var.enable_dedicated_management_vpc ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.management_public_az1]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_subnet" "public_subnet_az2" {
  count = var.enable_dedicated_management_vpc ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.management_public_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_subnet" "public_subnet_az3" {
  count = (var.enable_dedicated_management_vpc && var.availability_zone_3 != "") ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.management_public_az3]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  mgmt_az3_subnet_id = var.availability_zone_3 != "" ? (
    var.enable_dedicated_management_vpc ? one(data.aws_subnet.public_subnet_az3[*].id) : one(data.aws_subnet.inspection_management_az3[*].id)
  ) : null
}

# Security group for management interfaces
resource "aws_security_group" "management-vpc-sg" {
  count       = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? 1 : 0
  description = "Security Group for ENI in the management VPC"
  vpc_id      = var.enable_dedicated_management_vpc ? data.aws_vpc.management_vpc[0].id : data.aws_vpc.inspection.id
  ingress {
    description = "Allow management access from allowed CIDRs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.vpc_cidr_sg
  }
  egress {
    description = "Allow egress ALL"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#
# FortiManager integration (UMS)
#
# With fmg_integration.ums set, the module bootstraps every FortiGate with:
#   config system central-management   -> FortiManager address and serial number
#   config system auto-scale           -> set cloud-mode ums, callback-url = FortiManager
#   execute central-mgmt register-device-by-ip <fortimanager_ip> <fortimanager_api_key>
# and its Lambda function only builds the network interfaces and tracks the instances. It does
# not change the password, install a license, or push configuration: FortiManager does all
# three (auto-onboarding rule, FortiFlex connector, CLI template, policy package). The license
# type is "byol" because FortiFlex runs on the BYOL AMI.
#
locals {
  fmg_integration = {
    ip           = var.fortimanager_ip
    sn           = var.fortimanager_sn
    fgt_lic_mgmt = "fmg"
    vrf_select   = var.fortimanager_vrf_select
    primary_only = false
    ums = {
      autoscale_psksecret = var.ums_autoscale_psksecret
      fmg_password        = ""
      hb_interval         = var.ums_hb_interval
      api_key             = var.fortimanager_api_key
    }
  }

  dedicated_port = !var.enable_dedicated_management_vpc && !var.enable_dedicated_management_eni ? {} : {
    "dedicated_port" = {
      device_index     = local.management_device_index
      enable_public_ip = local.fgt_management_public_ip_effective
      subnet = concat(
        [
          {
            id        = var.enable_dedicated_management_vpc ? data.aws_subnet.public_subnet_az1[0].id : data.aws_subnet.inspection_management_az1[0].id
            zone_name = local.availability_zone_1
          },
          {
            id        = var.enable_dedicated_management_vpc ? data.aws_subnet.public_subnet_az2[0].id : data.aws_subnet.inspection_management_az2[0].id
            zone_name = local.availability_zone_2
          }
        ],
        var.availability_zone_3 != "" ? [
          {
            id        = local.mgmt_az3_subnet_id
            zone_name = local.availability_zone_3
          }
        ] : []
      )
      security_groups = [
        {
          id = aws_security_group.management-vpc-sg[0].id
        }
      ]
    }
  }
}

module "spk_tgw_gwlb_asg_fgt_igw" {
  # Fortinet registry module. Releases 1.1.4 and later support UMS (fmg_integration.ums); 1.1.7
  # is the release this template is tested against. After changing the version, run
  # `terraform init -upgrade` so the new release is downloaded.
  source  = "fortinetdev/cloud-modules/aws//examples/spk_tgw_gwlb_asg_fgt_igw"
  version = "1.1.7"

  ## Root config
  region        = var.aws_region
  module_prefix = var.asg_module_prefix

  # Use existing inspection VPC resources (looked up by Fortinet-Role tags)
  existing_security_vpc = {
    id = data.aws_vpc.inspection.id
  }
  existing_igw = {
    id = data.aws_internet_gateway.inspection.id
  }
  existing_tgw = {
  }

  # Distributed egress -- attaches a GWLB Endpoint per discovered distributed VPC to the same
  # GWLB Endpoint Service used by the Inspection VPC. See vpc_distributed_egress.tf.
  spk_vpc = local.distributed_spk_vpc

  existing_subnets = merge(
    {
      fgt_login_az1 = {
        id                = data.aws_subnet.inspection_public_az1.id
        availability_zone = local.availability_zone_1
      },
      fgt_login_az2 = {
        id                = data.aws_subnet.inspection_public_az2.id
        availability_zone = local.availability_zone_2
      },
      gwlbe_az1 = {
        id                = data.aws_subnet.inspection_gwlbe_az1.id
        availability_zone = local.availability_zone_1
      },
      gwlbe_az2 = {
        id                = data.aws_subnet.inspection_gwlbe_az2.id
        availability_zone = local.availability_zone_2
      },
      fgt_internal_az1 = {
        id                = data.aws_subnet.inspection_private_az1.id
        availability_zone = local.availability_zone_1
      },
      fgt_internal_az2 = {
        id                = data.aws_subnet.inspection_private_az2.id
        availability_zone = local.availability_zone_2
      }
    },
    var.availability_zone_3 != "" ? {
      fgt_login_az3 = {
        id                = data.aws_subnet.inspection_public_az3[0].id
        availability_zone = local.availability_zone_3
      },
      gwlbe_az3 = {
        id                = data.aws_subnet.inspection_gwlbe_az3[0].id
        availability_zone = local.availability_zone_3
      },
      fgt_internal_az3 = {
        id                = data.aws_subnet.inspection_private_az3[0].id
        availability_zone = local.availability_zone_3
      }
    } : {}
  )

  ## VPC
  security_groups = {
    secgrp1 = {
      description = "Security group by Terraform"
      ingress = {
        all_traffic = {
          from_port   = "0"
          to_port     = "0"
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
      egress = {
        all_traffic = {
          from_port   = "0"
          to_port     = "0"
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }

  vpc_cidr_block     = var.vpc_cidr_inspection
  spoke_cidr_list    = []
  availability_zones = var.availability_zone_3 != "" ? [local.availability_zone_1, local.availability_zone_2, local.availability_zone_3] : [local.availability_zone_1, local.availability_zone_2]

  ## Transit Gateway
  tgw_name        = "${var.cp}-${var.env}-tgw"
  tgw_description = "tgw for fortigate ums group"

  ## Auto scale group
  fgt_intf_mode            = var.firewall_policy_mode
  fgt_access_internet_mode = var.access_internet_mode
  fgt_config_shared = {
    fgt_login_port_number = var.fortigate_gui_port != "443" ? var.fortigate_gui_port : ""
  }
  asgs = {
    fgt_ums_asg = {
      template_name            = "fgt_ums_template"
      fgt_version              = var.fortios_version
      license_type             = "byol"
      instance_type            = var.fgt_instance_type
      fgt_password             = var.fortigate_admin_password
      keypair_name             = var.keypair
      fmg_integration          = local.fmg_integration
      extra_network_interfaces = local.dedicated_port
      intf_security_group = {
        login_port    = "secgrp1"
        internal_port = "secgrp1"
      }
      # Instance tags in the instance metadata, as in Fortinet's UMS Terraform example.
      metadata_options = {
        http_endpoint          = "enabled"
        http_tokens            = "optional"
        instance_metadata_tags = "enabled"
      }
      # Initial size. After deployment FortiManager sets the instance count (Device Manager >
      # right-click the UMS group > Auto-Scale Instance Count). See the Scaling chapter.
      asg_min_size                  = var.asg_min_size
      asg_max_size                  = var.asg_max_size
      asg_desired_capacity          = var.asg_desired_size
      create_dynamodb_table         = true
      dynamodb_table_name           = "fgt_ums_track_table"
      asg_health_check_grace_period = var.asg_health_check_grace_period
    }
  }

  ## Cloudwatch Alarm -- none: in UMS, FortiManager sets the instance count.
  cloudwatch_alarms = {}

  ## Gateway Load Balancer
  enable_cross_zone_load_balancing = var.allow_cross_zone_load_balancing
  gwlb_health_check = {
    port              = var.gwlb_health_check_port
    protocol          = "HTTP"
    path              = "/"
    matcher           = "200-399"
    interval          = var.gwlb_health_check_interval
    healthy_threshold = var.gwlb_healthy_threshold
  }

  ## Spoke VPC
  enable_east_west_inspection = true

  ## Tag
  general_tags = local.common_tags
}
