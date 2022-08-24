variable "prefix" { type = string }
variable "aws_region" { type = string }
variable "cidr" { type = string }
variable "admin_cidr" { type = string }
variable "transit_gateway_ips" { type = list(any) }
variable "transit_vpc_id" { type = string }
variable "transit_gw_name" { type = string }
variable "transit_gw_asn" { type = number }
variable "fake_onprem_asn" { type = number }
variable "key_name" { type = string }