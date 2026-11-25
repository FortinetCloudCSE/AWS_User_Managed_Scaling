variable "aws_region" {
  description = "The AWS region to use"
}
variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merged with base tags in provider.tf default_tags, which propagates to every AWS resource including those created by the upstream autoscale module."
  type        = map(string)
  default     = {}
}
variable "availability_zone_1" {
  description = "Availability Zone 1 for VPC"
}
variable "availability_zone_2" {
  description = "Availability Zone 2 for VPC"
}
variable "availability_zone_3" {
  description = "Availability Zone 3 for VPC (optional, leave empty for 2-AZ deployments)"
  default     = ""
}
variable "subnet_bits" {
  description = "Number of bits in the network portion of the subnet CIDR"
}
variable "public_subnet_index" {
  description = "Index of the public subnet"
  default     = 0
}
variable "gwlbe_subnet_index" {
  description = "Index of the management subnet"
  default     = 1
}
variable "private_subnet_index" {
  description = "Index of the private subnet"
  default     = 2
}
variable "natgw_subnet_index" {
  description = "Index of the NAT GW subnet"
  default     = 3
}
variable "access_internet_mode" {
  description = "Variable that defines how the fortigates in the autoscale group will access the internet. 'nat_gw' or 'eip'"
  type        = string
  default     = "nat_gw"
}
variable "fortigate_gui_port" {
  description = "Fortigate GUI Port"
  default     = "443"
  type        = string
}
variable "firewall_policy_mode" {
  description = "Firewall Policy Mode"
  type        = string
  default     = "2-arm"
}
variable "keypair" {
  description = "Keypair for instances that support keypairs"
}
variable "vpc_cidr_sg" {
  description = "List of CIDRs to allow in security group for management access"
  type        = list(string)
  default     = []
}
variable "cp" {
  description = "Customer Prefix to apply to all resources"
}
variable "env" {
  description = "The Tag Environment to differentiate prod/test/dev"
}
variable "enable_dedicated_management_vpc" {
  description = "Boolean to allow creation of dedicated management interface in management VPC"
  type        = bool
}
variable "enable_dedicated_management_eni" {
  description = "Boolean to allow creation of dedicated management subnets and ENI in the inspection VPC"
  type        = bool
}
variable "enable_fgt_management_public_ip" {
  description = "Boolean to attach a public IP to the FortiGate's dedicated management port (only relevant when enable_dedicated_management_vpc or enable_dedicated_management_eni is true). Forced off regardless of this setting when enable_dedicated_management_nat_gateway is true -- see that variable."
  type        = bool
  default     = true
}
variable "enable_dedicated_management_nat_gateway" {
  description = "Must match enable_dedicated_management_nat_gateway in existing_vpc_resources' tfvars. When true, the management VPC egresses through a single dedicated NAT Gateway instead of per-interface public IPs, so this forces the FortiGate's dedicated management interface to not receive a public IP either, regardless of enable_fgt_management_public_ip -- doesn't make sense to have both."
  type        = bool
  default     = false
}
variable "create_tgw_routes_for_existing" {
  description = "Boolean to allow creation of TGW routes for the existing_vpc_resources template"
  type        = bool
}
variable "enable_tgw_attachment" {
  description = "Allow Inspection VPC to attach to an existing TGW"
  type        = bool
}
variable "allow_cross_zone_load_balancing" {
  description = "Allow gateway load balancer to use healthy instances in a different zone"
  type        = bool
}
variable "asg_module_prefix" {
  description = "Prefix for the names of the resources the Fortinet module creates (Auto Scaling group, launch template, Lambda function, GWLB)"
  type        = string
  default     = ""
}
variable "vpc_cidr_inspection" {
  description = "CIDR for the whole NS inspection VPC"
}
variable "vpc_cidr_east" {
  description = "CIDR for the whole east VPC"
}
variable "vpc_cidr_west" {
  description = "CIDR for the whole west VPC"
}
variable "vpc_cidr_management" {
  description = "CIDR for the management VPC"
}
variable "spoke_cidrs" {
  description = "List of all spoke VPC CIDRs south of the TGW that need FortiGate east-west inspection routes. Leave empty to default to [vpc_cidr_east, vpc_cidr_west]; override with the real list of production spoke CIDRs if they differ from the demo east/west VPCs."
  type        = list(string)
  default     = []
}
variable "attach_to_tgw_name" {
  description = "Name of the TGW to attach to"
  type        = string
  default     = ""
}
#
# Distributed egress (dual-egress: centralized + distributed) feature
#
variable "enable_distributed_egress" {
  description = "Attach a GWLB Endpoint to each discovered distributed-egress VPC (tag-discovered lab VPCs from existing_vpc_resources, plus any explicit distributed_egress_endpoint_subnet_ids), sharing the same GWLB Endpoint Service used by the centralized/Inspection VPC path"
  type        = bool
  default     = false
}
variable "distributed_egress_endpoint_subnet_ids" {
  description = "Explicit list of GWLBe-placement subnet IDs in customer-owned distributed VPCs that this template doesn't otherwise discover via Fortinet-Role tags. A GWLB Endpoint is created in each, but -- unlike tag-discovered subnets -- their route tables are never modified; redirecting the customer's own route table to the new endpoint is left to the customer."
  type        = list(string)
  default     = []
}
variable "endpoint_name_az1" {
  description = "Name of the gwlb endpoint to route to in AZ1"
  type        = string
  default     = ""
}
variable "endpoint_name_az2" {
  description = "Name of the gwlb endpoint to route to in AZ2"
  type        = string
  default     = ""
}
variable "endpoint_name_az3" {
  description = "Name of the gwlb endpoint to route to in AZ3"
  type        = string
  default     = ""
}

variable "modify_existing_route_tables" {
  description = "Boolean to allow modification of existing route tables in the inspection VPC. When true, routes will be added to point private subnets to GWLB endpoints."
  type        = bool
  default     = true
}

variable "gwlb_health_check_port" {
  description = "Port for GWLB health check. Uses FortiGate probe-response port so health checks gate on config sync completion."
  type        = number
}

variable "gwlb_health_check_interval" {
  description = "Interval in seconds between GWLB health checks."
  type        = number
}

variable "gwlb_healthy_threshold" {
  description = "Number of consecutive health check successes required before considering a target healthy."
  type        = number
}


#
# FortiGate UMS group
#
variable "fortios_version" {
  description = "FortiOS version of the FortiGate instances, as X.Y.Z. UMS requires 7.6.4 or later (8.0 included). Must not be later than the FortiManager version."
  type        = string
  validation {
    condition = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.fortios_version)) && (
      (tonumber(split(".", var.fortios_version)[0]) == 7 && tonumber(split(".", var.fortios_version)[1]) == 6 && tonumber(split(".", var.fortios_version)[2]) >= 4) ||
      (tonumber(split(".", var.fortios_version)[0]) == 7 && tonumber(split(".", var.fortios_version)[1]) > 6) ||
      tonumber(split(".", var.fortios_version)[0]) > 7
    )
    error_message = "fortios_version must be X.Y.Z and 7.6.4 or later."
  }
}
variable "fgt_instance_type" {
  description = "EC2 instance type of the FortiGate instances. Must match the FortiFlex configuration (CPU count) that FortiManager uses to license them."
  type        = string
  default     = "c6i.xlarge"
}
variable "fortigate_admin_password" {
  description = "Password the bootstrap configuration sets for the FortiGate 'admin' user. FortiManager can change it later through a system template."
  type        = string
  sensitive   = true
}
variable "asg_min_size" {
  description = "Initial minimum size of the Auto Scaling group. After deployment, FortiManager sets the instance count."
  type        = number
  default     = 1
}
variable "asg_max_size" {
  description = "Initial maximum size of the Auto Scaling group. After deployment, FortiManager sets the instance count."
  type        = number
  default     = 1
}
variable "asg_desired_size" {
  description = "Initial desired size of the Auto Scaling group. After deployment, FortiManager sets the instance count."
  type        = number
  default     = 1
}
variable "asg_health_check_grace_period" {
  description = "Seconds after an instance comes into service before the Auto Scaling group acts on the GWLB health check. The FortiGate passes the health check only after FortiManager has onboarded it and installed the CLI template (probe-response), so allow for onboarding, licensing (one reboot) and the install."
  type        = number
  default     = 1200
}

#
# FortiManager (required for UMS)
#
variable "fortimanager_ip" {
  description = "FortiManager address the FortiGates register to (central-management and the auto-scale callback-url). Use FortiManager's fixed private IP when the FortiGates reach it privately (dedicated management VPC or Transit Gateway), or its Elastic IP when they reach it over the internet."
  type        = string
  validation {
    condition     = can(cidrhost("${var.fortimanager_ip}/32", 0))
    error_message = "fortimanager_ip must be an IPv4 address."
  }
}
variable "fortimanager_sn" {
  description = "Serial number of the FortiManager (Dashboard > System Information, or 'get system status')."
  type        = string
  validation {
    condition     = length(var.fortimanager_sn) > 0
    error_message = "fortimanager_sn is required."
  }
}
variable "fortimanager_api_key" {
  description = "API key of the FortiManager REST API administrator used by the auto-onboarding rule (System Settings > Administrators > REST API Admin, with Automatic Register enabled). The FortiGates use it to register themselves."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.fortimanager_api_key) > 0
    error_message = "fortimanager_api_key is required."
  }
}
variable "fortimanager_vrf_select" {
  description = "VRF the FortiGates use to reach FortiManager (central-management vrf-select). Leave null for the default VRF. The interface must already be in that VRF when the FortiGate boots, so keep null unless the bootstrap places the interface in the VRF."
  type        = number
  default     = null
}
variable "ums_autoscale_psksecret" {
  description = "Pre-shared secret of 'config system auto-scale' on the FortiGates of the UMS group."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.ums_autoscale_psksecret) > 0
    error_message = "ums_autoscale_psksecret is required."
  }
}
variable "ums_hb_interval" {
  description = "Seconds between auto-scale heartbeat packets (config system auto-scale hb-interval)."
  type        = number
  default     = 10
}
