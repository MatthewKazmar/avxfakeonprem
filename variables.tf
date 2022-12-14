variable "prefix" { type = string }
variable "aws_region" { type = string }
variable "cidr" { type = string }
variable "admin_cidrs" { type = list(any) }
variable "transit_gw_ips" { type = list(any) }
variable "transit_vpc_id" { type = string }
variable "transit_gw_name" { type = string }
variable "transit_gw_asn" { type = number }
variable "fake_onprem_asn" { type = number }
variable "key_name" { type = string }
variable "tags" { type = map(any) }
variable "volume_tags" { type = map(any) }

# Set up the tunnel IPs for the ipsec-vti.sh script
locals {
  transit_gw_ips_as_cidrs = [for ip in var.transit_gw_ips : "${ip}/32"]
  #local and remove are from remote device perspective.
  local_tunnel_cidr  = split(",", aviatrix_transit_external_device_conn.fake_onprem.local_tunnel_cidr)
  remote_tunnel_cidr = split(",", aviatrix_transit_external_device_conn.fake_onprem.remote_tunnel_cidr)
  vti_gw             = replace("${local.local_tunnel_cidr[0]} ${local.remote_tunnel_cidr[0]}", "/", "\\/")
  vti_hagw           = replace("${local.local_tunnel_cidr[1]} ${local.remote_tunnel_cidr[1]}", "/", "\\/")
  neighbor_gw        = split("/", local.local_tunnel_cidr[0])[0]
  neighbor_hagw      = split("/", local.local_tunnel_cidr[1])[0]
  vpn_subnet         = cidrsubnet(var.cidr, 1, 0)
  test_subnet        = cidrsubnet(var.cidr, 1, 1)
}