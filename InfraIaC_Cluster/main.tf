provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "ubuntu_nodes" {
  count         = 3
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  vpc_security_group_ids = var.vpc_security_group_id

  tags = {
    Name = var.Name
  }
}