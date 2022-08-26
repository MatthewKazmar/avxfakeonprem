output "vpn_vm_ip" {
  description = "Public IP of VPN VM"
  value       = module.vpn_vm_eip.public_ip
}

output "vpn_vm_ip" {
  description = "Public IP of Test VM"
  value       = module.test_vm.public_ip
}