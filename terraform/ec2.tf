locals {
  instance_count = 2
}
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name      = "ec2_shutdown_vpc"
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name      = "ec2_shutdown_subnet"
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_network_interface" "interface_default" {
  count     = local.instance_count
  subnet_id = aws_subnet.subnet.id
  tags = {
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_instance" "instance_default" {
  count         = local.instance_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.interface_default[count.index].id
    device_index         = 0
  }
  tags = {
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_security_group" "open_ssh" {
  name        = "Open SSH from World"
  description = "Open SSH from World"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_network_interface" "interface_ssh" {
  count     = local.instance_count
  subnet_id = aws_subnet.subnet.id
  tags = {
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_instance" "instance_ssh" {
  count                  = local.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.open_ssh.id]
  tags = {
    Candidate = "Sara Angel-Murphy"
  }
  network_interface {
    network_interface_id = aws_network_interface.interface_ssh[count.index].id
    device_index         = 0
  }
}

resource "aws_network_interface" "interface_ignore" {
  count     = local.instance_count
  subnet_id = aws_subnet.subnet.id
  tags = {
    Candidate = "Sara Angel-Murphy"
  }
}

resource "aws_instance" "instance_ignore" {
  count                  = local.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.open_ssh.id]
  tags = {
      Candidate = "Sara Angel-Murphy",
      shutdown_service_excluded = "True"
  }
  network_interface {
    network_interface_id = aws_network_interface.interface_ssh[count.index].id
    device_index         = 0
  }
}
