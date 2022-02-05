terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.0"
    }
  }
}





provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

variable "vpc" {
  description = "digite VPC x.x.x.x/xx"
  type        = string
  #default     = "10.0.0.0/16"
}

resource "aws_vpc" "vpc_aula" {
  cidr_block = var.vpc
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc_aula.id

  tags = {
    Name = "gateway_aula"
  }
}

resource "aws_route_table" "rotas" {
  vpc_id = aws_vpc.vpc_aula.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "rotas_aula"
  }
}


resource "aws_subnet" "subrede" {
  vpc_id            = aws_vpc.vpc_aula.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "subnet_aula"
  }
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table_association" "associacao" {
  subnet_id      = aws_subnet.subrede.id
  route_table_id = aws_route_table.rotas.id
}

resource "aws_security_group" "abrir_portas" {
  name        = "abrir_portas"
  description = "Abrir portas para aula BRQ - Grande Porte"
  vpc_id      = aws_vpc.vpc_aula.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "abrir_portas"
  }
}


resource "aws_network_interface" "interface" {
  subnet_id       = aws_subnet.subrede.id
  private_ips     = ["10.0.1.42"]
  security_groups = [aws_security_group.abrir_portas.id]
  tags = {
    Name = "interface"
  }
}

resource "aws_network_interface" "interface_bd" {
  subnet_id       = aws_subnet.subrede.id
  private_ips     = ["10.0.1.43"]
  security_groups = [aws_security_group.abrir_portas.id]
  tags = {
    Name = "interface"
  }
}

resource "aws_eip" "ip_pub" {
  vpc                       = true
  network_interface         = aws_network_interface.interface.id
  associate_with_private_ip = "10.0.1.42"
  depends_on                = [aws_internet_gateway.gw]
}

resource "aws_eip" "ip_pub_bd" {
  vpc                       = true
  network_interface         = aws_network_interface.interface_bd.id
  associate_with_private_ip = "10.0.1.43"
  depends_on                = [aws_internet_gateway.gw]
}

output "ip_publico" {
  value = aws_eip.ip_pub.public_ip
}

output "ip_publico_bd" {
  value = aws_eip.ip_pub_bd.public_ip
}

resource "aws_instance" "web" {
  ami               = "ami-04505e74c0741db8d"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "brq"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.interface.id
  }
  user_data = <<-EOF
		            #! /bin/bash
		            sudo bash -c 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJEAUySHoDCHm0PEVhs7wdvxikBDFcwDamepKR11VI03 ansible"  > .ssh/authorized_keys'
	            EOF

  tags = {
    Name = "web_server"
  }
}

resource "aws_instance" "banco" {
  ami               = "ami-04505e74c0741db8d"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "brq"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.interface_bd.id
  }
  user_data = <<-EOF
		            #! /bin/bash
		            sudo bash -c 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJEAUySHoDCHm0PEVhs7wdvxikBDFcwDamepKR11VI03 ansible"  > .ssh/authorized_keys'
	            EOF

  tags = {
    Name = "banco_de_dados"
  }
}
