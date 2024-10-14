terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# provider "azurerm" {
#   resource_provider_registrations = "none"
#   features {}
# }

# resource "azurerm_resource_group" "sydney" {
#   name     = "example-resources"
#   location = "West Europe"
# }


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_availability_zone" "available" {
  name = "ap-southeast-2b"
}

resource "aws_vpc" "web_server_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "web-server-vpc"
  }
}

resource "aws_subnet" "web_server_vpc_subnet_public2" {
  vpc_id            = aws_vpc.web_server_vpc.id
  availability_zone = data.aws_availability_zone.available.name
  cidr_block        = "10.0.2.0/24"

  tags = {
    Name = "web-server-vpc-subnet-public2"
  }
}

resource "aws_subnet" "web_server_vpc_subnet_private2" {
  vpc_id            = aws_vpc.web_server_vpc.id
  availability_zone = data.aws_availability_zone.available.name
  cidr_block        = "10.0.4.0/24"

  tags = {
    Name = "web-server-vpc-subnet-private2"
  }
}

resource "aws_internet_gateway" "web_server_igw" {
  vpc_id = aws_vpc.web_server_vpc.id

  tags = {
    Name = "web-server-igw"
  }
}

resource "aws_route_table" "web_server_vpc_rtb_public" {
  vpc_id = aws_vpc.web_server_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web_server_igw.id
  }

  route {
    cidr_block = aws_vpc.web_server_vpc.cidr_block
    gateway_id = "local"
  }

  tags = {
    Name = "web-server-rtb-public"
  }
}

resource "aws_route_table" "web_server_vpc_rtb_private" {
  vpc_id = aws_vpc.web_server_vpc.id

  route {
    cidr_block = aws_vpc.web_server_vpc.cidr_block
    gateway_id = "local"
  }

  tags = {
    Name = "web-server-rtb-private"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.web_server_vpc_subnet_public2.id
  route_table_id = aws_route_table.web_server_vpc_rtb_public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.web_server_vpc_subnet_private2.id
  route_table_id = aws_route_table.web_server_vpc_rtb_private.id
}

resource "aws_network_acl" "web_server_nacl" {
  vpc_id = aws_vpc.web_server_vpc.id

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 102
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 103
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 104
    action     = "allow"
    cidr_block = "172.17.3.0/24"
    from_port  = 3306
    to_port    = 3306
  }

  ingress {
    protocol   = "icmp"
    rule_no    = 105
    action     = "allow"
    cidr_block = "10.0.4.0/24"
    from_port  = 8
    to_port    = 0
  }

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 102
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 103
    action     = "allow"
    cidr_block = "172.17.3.0/24"
    from_port  = 3306
    to_port    = 3306
  }

  egress {
    protocol   = "icmp"
    rule_no    = 104
    action     = "allow"
    cidr_block = "10.0.4.0/24"
    from_port  = 8
    to_port    = 0
  }
  tags = {
    Name = "web-server-subnet-public2-nacl"
  }
}

resource "aws_security_group" "web_server_security_group" {
  name        = "Web Sever Security Group"
  description = "Security group for the web server"
  vpc_id      = aws_vpc.web_server_vpc.id

  tags = {
    Name = "Web Sever Security Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_server_allow_https" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "web_server_allow_http" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "web_server_allow_ssh" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "web_server_allow_icmp" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = "10.0.4.0/24"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
}

resource "aws_vpc_security_group_egress_rule" "web_server_allow_mysql" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = "172.17.3.0/24"
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
}

resource "aws_vpc_security_group_egress_rule" "web_server_allow_all_traffic" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = "10.0.4.0/24"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
}


resource "aws_security_group" "test_instance_security_group" {
  name        = "Test Instance Security Group"
  description = "Security group for the test instance"
  vpc_id      = aws_vpc.web_server_vpc.id

  tags = {
    Name = "Test Instance Security Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "test_instance_allow_all_traffic" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = "10.0.2.0/24"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
}

resource "aws_vpc_security_group_egress_rule" "test_instance_allow_all_traffic" {
  security_group_id = aws_security_group.web_server_security_group.id
  cidr_ipv4         = "10.0.2.0/24"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
}


# resource "aws_instance" "web_server_instance" {
#   ami           = data.aws_ami.ubuntu.id
#   instance_type = "t2.micro"

#   tags = {
#     Name = "web-server-instance"
#   }
# }



