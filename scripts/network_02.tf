resource "aws_vpc" "vpc_attacker" {
  cidr_block           = "20.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "Attacker VPC"
  }
}


resource "aws_subnet" "public_subnet_attacker" {
  vpc_id     = aws_vpc.vpc_attacker.id
  cidr_block = "20.0.1.0/24"

  tags = {
    Name = "Public Subnet of Attacker VPC"
  }
}


resource "aws_internet_gateway" "ig_attacker" {
  vpc_id = aws_vpc.vpc_attacker.id

  tags = {
    Name = "Internet Gateway of Attacker VPC"
  }
}

resource "aws_route_table" "new_rt_attacker" {
  vpc_id = aws_vpc.vpc_attacker.id

  tags = {
    Name = "New Route Table for Attacker VPC"
  }
}

resource "aws_route" "new_rt_02_route" {
  route_table_id         = aws_route_table.new_rt_attacker.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig_attacker.id
}

resource "aws_route_table_association" "subnect_assoc_for_vpc_attacker" {
  subnet_id      = aws_subnet.public_subnet_attacker.id
  route_table_id = aws_route_table.new_rt_attacker.id
}

resource "aws_security_group" "sg_attacker" {
  name        = "kali-sg-vpc_attacker"
  description = "SG of Kali Instance in Attacker VPC"
  vpc_id      = aws_vpc.vpc_attacker.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "kali_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["kali-last-snapshot-amd64-2024*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "vm_kali" {
  ami           = data.aws_ami.kali_linux.id
  instance_type = "t3.medium"

  tags = {
    Name = "vm-kali"
  }

  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnet_attacker.id
  vpc_security_group_ids      = [aws_security_group.sg_attacker.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp2"
  }

  user_data = <<-EOF
    #!/bin/bash
    # Update package list and configure dpkg if necessary
    sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a
    sudo apt update
    
    # Install post-exploitation tools
    sudo DEBIAN_FRONTEND=noninteractive apt install -y kali-tools-post-exploitation
    
    # Create usernames.txt in /root
    cat <<EOL > /root/usernames.txt
    admin
    root
    ubuntu
    adminuser
    adminuser2
    EOL
    
    # Create passwords.txt in /root
    cat <<EOL > /root/passwords.txt
    password
    123456
    12345678
    pass123
    EOL
    
    # Restart SSH to apply any configuration changes
    systemctl restart ssh
  EOF
}

output "vm_kali_private_ip" {
  value = aws_instance.vm_kali.private_ip
}

output "vm_kali_public_ip" {
  value = aws_instance.vm_kali.public_ip
}
