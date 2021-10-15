provider "aws" {
    region = "us-east-1"
    access_key = "AKIA5NBFC6I6FUSNOIN7"
    secret_key = "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"
}

#1. Create VPC

resource "aws_vpc" "web_vpc"{
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "WebVPC"
    }
}
# 2. Create Internet Gateway
resource "aws_internet_gateway" "web_IG" {
  vpc_id = aws_vpc.web_vpc.id

  tags = {
    Name = "webIG"
  }
}

# 3. Create Custom Route Table
resource "aws_route_table" "web_route_table" {
  vpc_id = aws_vpc.web_vpc.id

  route   {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.web_IG.id
    }
    route {
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.web_IG.id
    }
  
  tags = {
    Name = "web_route-table"
  }
}

# 4. Create Subnet

resource "aws_subnet" "sub-1"{
    vpc_id = aws_vpc.web_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "web-subnet"
    }
}
# 5. Association Subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sub-1.id
  route_table_id = aws_route_table.web_route_table.id
}
# 6. Security Group to allow port 22,80,443
resource "aws_security_group" "web_allow_tls" {
  name        = "allow_tls"
  description = "Web allow TLS inbound traffic"
  vpc_id      = aws_vpc.web_vpc.id

  ingress  {
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      }

  ingress {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      }
  

  ingress  {
      description      = "ssh"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      }
  

  egress  {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

  tags = {
    Name = "web_allow_tls"
  }
}
# 7. Create a network interface with an IP in the  subnet 
resource "aws_network_interface" "Web-server-nic" {
  subnet_id       = aws_subnet.sub-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.web_allow_tls.id]

}

# 8. Assign as Elastic IP  to the network interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.Web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.web_IG]
}

# 9. Create ubuntu server with web code 
resource "aws_instance" "web" {
    ami = "ami-09e67e426f25ce0d7"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "Terraform"
    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.Web-server-nic.id
    }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo my first page > /var/www/html/index.html'
                EOF
    tags = {
        Name = "web_server"
    }

}
