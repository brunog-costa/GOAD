provider "twingate" {
  api_token = var.twingate_api_token
  network   = var.twingate_network
}

resource "twingate_remote_network" "aws_network" {
  name = "GOAD_AWS"
}

resource "twingate_connector" "aws_connector" {
  remote_network_id = twingate_remote_network.aws_network.id
}

resource "twingate_connector_tokens" "aws_connector_tokens" {
  connector_id = twingate_connector.aws_connector.id
}

resource "twingate_resource" "lab_network" {
  name              = "GOAD-jumpbox"
  address           = "192.168.56.100"
  remote_network_id = twingate_remote_network.aws_network.id
  
  protocols = {
    allow_icmp = true
    tcp = {
      policy = "ALLOW_ALL"
    }
    udp = {
      policy = "ALLOW_ALL"
    }
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "goad-jumpbox-keypair" {
  key_name   = "GOAD-jumpbox-keypair"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_network_interface" "goad-vm-nic-jumpbox" {
  subnet_id       = aws_subnet.goad_public_network.id
  private_ips     = ["192.168.56.100"]
  security_groups = [aws_security_group.goad_provision_security_group.id]
  attachment {
    instance = aws_instance.goad-vm-jumpbox.id
    device_index = 1 
  }
  tags = {
    Lab = "GOAD"
  }
}

data "aws_ami" "ubuntu_latest" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["*ubuntu-noble-24.04-amd64-server*"]
  }
}

resource "aws_instance" "goad-vm-jumpbox" {
  ami           = data.aws_ami.ubuntu_latest.id
  instance_type = "t2.medium"

  # network_interface {
  #   network_interface_id = aws_network_interface.goad-vm-nic-jumpbox.id
  #   device_index         = 1
  # }

  associate_public_ip_address = true
  availability_zone = var.zone
  key_name                    = "GOAD-jumpbox-keypair"

  user_data = <<EOF
#!/bin/bash
usermod -l "${var.jumpbox_username}" ubuntu  
usermod -d "/home/${var.jumpbox_username}" -m ${var.jumpbox_username}
sed -i "s/ubuntu/${var.jumpbox_username}/" /etc/sudoers.d/90-cloud-init-users
set -e
# Install Twingate
curl "https://binaries.twingate.com/connector/setup.sh" | sudo TWINGATE_ACCESS_TOKEN="${twingate_connector_tokens.aws_connector_tokens.access_token}" TWINGATE_REFRESH_TOKEN="${twingate_connector_tokens.aws_connector_tokens.refresh_token}" TWINGATE_NETWORK="${var.twingate_network}" TWINGATE_LABEL_DEPLOYED_BY="linux" bash
  EOF 

  tags = {
    Name = "GOAD-jumpbox"
    Lab  = "GOAD"
  }

  root_block_device {
    volume_size = var.jumpbox_disk_size
    encrypted   = true
    tags = {
      Name = "JumpBox-root"
      Lab  = "GOAD"
    }
  }

  provisioner "local-exec" {
    command = "echo '${tls_private_key.ssh.private_key_openssh}' > ../ssh_keys/ubuntu-jumpbox.pem && echo '${tls_private_key.ssh.public_key_openssh}' > ../ssh_keys/ubuntu-jumpbox.pub && chmod 600 ../ssh_keys/*"
  }

  lifecycle {
    ignore_changes = [associate_public_ip_address]
  }
}

