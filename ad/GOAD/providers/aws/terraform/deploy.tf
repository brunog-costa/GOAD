terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "tls_private_key" "windows" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

variable "vm_config" {
  type = map(object({
    name               = string
    domain             = string
    instance_type      = string
    private_ip_address = string
    password           = string
  }))

  default = {
    "dc01" = {
      name               = "dc01"
      domain             = "sevenkingdoms.local"
      instance_type      = "t3.medium"
      private_ip_address = "192.168.56.10"
      password           = "8dCT-DJjgScp"
    }
    "dc02" = {
      name               = "dc02"
      domain             = "north.sevenkingdoms.local"
      instance_type      = "t3.medium"
      private_ip_address = "192.168.56.11"
      password           = "NgtI75cKV+Pu"
    }
    "dc03" = {
      name               = "dc03"
      domain             = "essos.local"
      instance_type      = "t3.medium"
      private_ip_address = "192.168.56.12"
      password           = "Ufe-bVXSx9rk"
    }
    "srv02" = {
      name               = "srv02"
      domain             = "north.sevenkingdoms.local"
      instance_type      = "t3.medium"
      private_ip_address = "192.168.56.22"
      password           = "NgtI75cKV+Pu"
    }
    "srv03" = {
      name               = "srv03"
      domain             = "essos.local"
      instance_type      = "t3.medium"
      private_ip_address = "192.168.56.23"
      password           = "978i2pF43UJ-"
    }
  }
}

# Keys are automagically generated and written in the ssh_keys folder. You can provide your own if you like.
resource "aws_key_pair" "goad-windows-keypair" {
  key_name   = "GOAD-windows-keypair"
  public_key = tls_private_key.windows.public_key_openssh
}

data "aws_ami" "windows_2019"{
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["Windows_Server-2019-English-Full-Base*"]
  }
}

resource "aws_network_interface" "goad-vm-nic" {
  for_each = var.vm_config
  subnet_id   = aws_subnet.goad_private_network.id
  private_ips = [each.value.private_ip_address]
  security_groups = [aws_security_group.goad_security_group.id]
  tags = {
    Lab = "GOAD"
  }
}

resource "aws_instance" "goad-vm" {
  for_each = var.vm_config

  ami                    = data.aws_ami.windows_2019.id
  instance_type          = each.value.instance_type

  network_interface {
    network_interface_id = aws_network_interface.goad-vm-nic[each.key].id
    device_index = 0
  }

  user_data = templatefile("${path.module}/user_data/instance-init.ps1.tpl", {
                                username = var.username
                                password = each.value.password
                                domain = each.value.domain
                           })
  key_name = "GOAD-windows-keypair"
  tags = {
    Name = "GOAD-${each.value.name}"
    Lab = "GOAD"
  }
  provisioner "local-exec" {
    command = "echo '${tls_private_key.windows.private_key_pem}' > ../ssh_keys/id_rsa_windows && echo '${tls_private_key.windows.public_key_pem}' > ../ssh_keys/id_rsa_windows.pub && chmod 600 ../ssh_keys/id_rsa*"
  }
}
