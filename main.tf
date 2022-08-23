# Create AWS EIP for VPN VM
# Do this first so we can build the Avx VPN Tunnel
resource "aws_eip" "vpn_vm_eip" {}

# Aviatrix BGPoIPSec External Connection
resource "aviatrix_transit_external_device_conn" "fake_onprem" {
  vpc_id            = var.transit_vpc_id
  connection_name   = "${var.prefix}-fake-onprem"
  gw_name           = var.transit_gw_name
  connection_type   = "bgp"
  tunnel_protocol   = "IPSec"
  enable_ikev2      = true
  bgp_local_as_num  = var.transit_gateway_asn
  bgp_remote_as_num = var.fake_onprem_asn
  remote_gateway_ip = aws_eip.vpn_vm_eip.address
}

# AWS VPC for StrongSwan/FRR
module "fake_onprem_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.prefix}-fake-onprem"
  cidr = var.cidr

  azs            = ["${var.aws_region}b"]
  public_subnets = [cidrsubnet(var.cidr, 1, 0), cidrsubnet(var.cidr, 1, 1)]

  enable_nat_gateway = false
  enable_vpn_gateway = false

}

# Security Groups
resource "aws_security_group" "vpn_vm_sg" {
  name        = "${var.prefix}-vpn-vm-sg"
  description = "allow IKE/NAT-T/ssh/routed traffic"
  vpc_id      = module.fake_onprem_vpc.id

  ingress {
    from_port   = 500
    to_port     = 500
    protocol    = "UDP"
    cidr_blocks = var.transit_gateway_ips
  }

  ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "UDP"
    cidr_blocks = var.transit_gateway_ips
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = var.admin_cidr
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
}

resource "aws_security_group" "test_vm_sg" {
  name        = "${var.prefix}-test-vm-sg"
  description = "allow ssh"
  vpc_id      = module.fake_onprem_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = var.admin_cidr
  }
}

resource "aws_eip" "vpn_vm_eip" {}

# Vpn VM
module "vpn_vm" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "${var.prefix}-vpn"

  ami                         = "ami-052efd3df9dad4825" #Ubuntu 22.04
  instance_type               = "t3.micro"
  key_name                    = var.key_name
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.vpn_vm_sg.id]
  subnet_id                   = module.fake_onprem_vpc.public_subnets[0]
  source_dest_check           = false

  depends_on = [
    aws_security_group.vpn_vm_sg,
    module.fake_onprem_vpc
  ]

  user_data = <<EOF
# Install StrongSwan/FRR
apt update
apt install -y strongswan strongswan-pki frr

# Stop services so we can config
systemctl stop strongswan-starter
systemctl stop frr

# Disable charon routes
sed -i "s/# install_routes = yes/install_routes = no/g" /etc/strongswan.d/charon.conf 

# Create ipsec.secrets
echo "${var.transit_gateway_ips[0]} : PSK \"${resource.aviatrix_transit_external_device_conn.fake_onprem.pre_shared_key}\"" > /etc/ipsec.secrets
echo "${var.transit_gateway_ips[0]} : PSK \"${resource.aviatrix_transit_external_device_conn.fake_onprem.pre_shared_key}\"" >> /etc/ipsec.secrets

# Get vti tunnel script
curl https://raw.githubusercontent.com/MatthewKazmar/avxfakeonprem/main/ipsec-vti.sh -o /var/lib/strongswan/ipsec-vti.sh
chmod +x /var/lib/strongswan/ipsec-vti.sh

# Get baseline ipsec.conf
curl https://raw.githubusercontent.com/MatthewKazmar/avxfakeonprem/main/ipsec.conf -o /etc/ipsec.conf

# Create sed template for ipsec.conf and frr.conf
template="s/:remote-as:/${var.fake_onprem_asn}/g\n"
template+="s/

# Frr config
sed -i 's/bgpd=no/bgpd=yes/g' /etc/frr/daemons
sed -i 's/#frr_profile="datacenter"/frr_profile="datacenter"/g' /etc/frr/daemons

EOF
}

resource "aws_eip_association" "vpn_vm_eip_association" {
    instance = module.vpn_vm.id
    allocation_id = aws_eip.vpn_vm_eip.id
}

resource "aws_eip" "vpn_vm_eip" {
  vpc      = true
  instance = module.vpn_vm.id

  depends_on = [
    module.vpn_vm,
    module.fake_onprem_vpc
  ]
}

# Test VM
module "test_vm" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "${var.prefix}-test"

  ami                    = "ami-0cff7528ff583bf9a" #Amazon Linux 2
  instance_type          = "t3.medium"
  key_name               = var.key_name
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.test_vm_sg.id]
  subnet_id              = module.fake_onprem_vpc.public_subnets[1]

  depends_on = [
    aws_security_group.test_vm_sg
  ]
}