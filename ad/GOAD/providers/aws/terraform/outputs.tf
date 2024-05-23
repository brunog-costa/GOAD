output "ubuntu-jumpbox-ip" {
  value = aws_network_interface.goad-vm-nic-jumpbox.private_dns_name
}