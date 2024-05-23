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
  security_groups = [aws_security_group.goad_security_group.id]
  tags = {
    Lab = "GOAD"
  }
}

data "aws_ami" "twingate" {
  most_recent = true
  filter {
    name = "name"
    values = [
      "twingate/images/hvm-ssd/twingate-amd64-*",
    ]
  }
  owners = ["617935088040"]
}

resource "aws_instance" "goad-vm-jumpbox" {
  ami           = data.aws_ami.twingate.id
  instance_type = "t2.medium"

  network_interface {
    network_interface_id = aws_network_interface.goad-vm-nic-jumpbox.id
    device_index         = 0
  }
  key_name = "GOAD-jumpbox-keypair"
  
  user_data = templatefile("${path.module}/user_data/instance-init.sh.tpl", {
    username      = var.jumpbox_username
    url           = "https://${var.twingate_network}.twingate.com"
    access_token  = "${twingate_connector_tokens.aws_connector_tokens.access_token}"
    refrent_token = "${twingate_connector_tokens.aws_connector_tokens.refresh_token}"
  })

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
}

