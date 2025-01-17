locals {
  instance_type = "t3.nano"
  ami           = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20221212"
  ami_type      = "hvm"
  ami_owner     = "099720109477"
  volume_type   = "gp3"
  volume_size   = 10
}

resource "aws_key_pair" "this" {
  key_name   = "${local.name}-keypair"
  public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
}

data "aws_ami" "this" {
  filter {
    name   = "name"
    values = [local.ami]
  }
  filter {
    name   = "virtualization-type"
    values = [local.ami_type]
  }
  owners      = [local.ami_owner]
  most_recent = true
}

resource "aws_security_group" "public" {
  name        = "${local.name}-public-ec2-sg"
  description = "security group for public EC2 "
  vpc_id      = aws_vpc.this.id

  ingress {
    description      = "port 80 for nginx"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "port 22 for ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "port 3128 for proxy"
    from_port        = 3128
    to_port          = 3128
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${local.name}-public-ec2-sg" }
}


resource "aws_instance" "public" {
  ami           = data.aws_ami.this.id
  instance_type = local.instance_type
  key_name      = aws_key_pair.this.key_name

  subnet_id = aws_subnet.public[0].id

  vpc_security_group_ids = [aws_security_group.public.id]

  root_block_device {
    volume_type = local.volume_type
    volume_size = local.volume_size
  }

  user_data = <<EOT
#!/bin/bash
apt update
apt -qqy install squid nginx apache2-utils --no-install-recommends
systemctl enable nginx
systemctl start nginx


cat << EOF > /etc/squid/squid.conf
http_port 3128
acl Safe_ports port 80 443
http_access deny !Safe_ports
http_access allow manager localhost
http_access deny manager

# user/pass auth is required
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
acl ncsa proxy_auth REQUIRED
http_access allow ncsa

http_access deny all
EOF

htpasswd -bc /etc/squid/passwd ${var.username} ${var.password}

systemctl enable squid
systemctl restart squid
EOT

  tags = { Name = "${local.name}-public-ec2" }
}


resource "aws_instance" "client" {
  ami           = data.aws_ami.this.id
  instance_type = local.instance_type
  key_name      = aws_key_pair.this.key_name

  subnet_id = aws_subnet.public[0].id

  vpc_security_group_ids = [aws_security_group.public.id]

  root_block_device {
    volume_type = local.volume_type
    volume_size = local.volume_size
  }


  tags = { Name = "${local.name}-client-ec2" }
}