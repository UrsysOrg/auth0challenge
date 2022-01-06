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

resource "aws_network_interface" "interface" {
  count       = var.instance_count
  subnet_id   = aws_subnet.subnet.id
  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_instance" "instance" {
  count         = var.instance_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.interface[count.index].id
    device_index         = 0
  }
}
