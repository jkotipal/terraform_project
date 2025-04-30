# author- jaya chandra naveen
# date_created -- 30-04-2025
# script to run the app in browser.

provider "aws" {
  region = "eu-north-1"
}

variable "cidr" {
  default = "10.0.0.0/16"
}

resource "aws_key_pair" "example" {
  key_name   = "master"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from internet"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-sg"
  }
}

resource "aws_instance" "server" {
  ami                         = "ami-0c1ac8a41498c1a9c" # Make sure this AMI is compatible with your region and needs
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.example.key_name
  vpc_security_group_ids      = [aws_security_group.webSg.id]
  subnet_id                   = aws_subnet.sub1.id
  associate_public_ip_address = true

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }

  # Copy the app.py file to the instance
  provisioner "file" {
    source      = "app.py"
    destination = "/home/ubuntu/app.py"
  }

  # Install Python dependencies and run the app
  provisioner "remote-exec" {
    inline = [
      "set -x",  # Enable debugging output
      "sudo apt update -y",
      "sudo apt install -y python3-pip python3-venv",  # Install pip and venv
      "cd /home/ubuntu",
      "python3 -m venv myenv",  # Create the virtual environment
      "myenv/bin/pip install flask",  # Install Flask in the virtual environment
      "myenv/bin/python app.py",  # Run the app using the virtual environment's Python
    ]
  }
}
# if any process is occupied by the port 8080, check with "sudo lsof -i :8080" and then kill by "sudo kill <port num>"
# then run the "myenv/bin/python app.py" again to open the port and run the app.
# search with "<publicIP>:8080" in browser.
#make sure 8080 port is created in inbound rules and exposed.
