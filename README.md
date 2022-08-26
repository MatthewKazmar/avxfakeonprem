# avxfakeonprem
Fake on-prem deployment with VPN to Aviatrix Transit

Initial deploy to AWS Only

# Build out fake onprem and connect to it.
A test Linux VM is created in another subnet.
Uses Ubuntu 22.04, FRR, Strongswan.

module "onprem" {
  source = "github.com/MatthewKazmar/avxfakeonprem"

  prefix          = local.pov_name
  aws_region      = var.aws_region
  cidr            = local.onprem_cidr
  admin_cidrs     = var.admin_cidrs
  transit_gw_ips  = [module.aws_transit.transit_gateway.eip, module.aws_transit.transit_gateway.ha_eip]
  transit_vpc_id  = module.aws_transit.vpc.vpc_id
  transit_gw_name = module.aws_transit.transit_gateway.gw_name
  transit_gw_asn  = module.aws_transit.transit_gateway.local_as_number
  fake_onprem_asn = var.onprem_asn
  key_name        = aws_key_pair.aws_key.key_name
}
