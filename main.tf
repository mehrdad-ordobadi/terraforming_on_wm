provider "aws" {
  region = "us-east-1"  # Replace with your preferred AWS region
#   profile = "personal-aws" # replace with your AWS CLI profile`
}

# Create your VPC
resource "aws_vpc" "coderunner_vpc" {
  cidr_block =  "10.0.0.0/16" # CIDR block for the VPC
  tags = {
    Name = "coderunner_vpc" # Name of your VPC
  }
}   

# Create a internet gateway
resource "aws_internet_gateway" "cr_igw" {
  vpc_id = aws_vpc.coderunner_vpc.id
  tags = {
    Name = "coderunner_igw"
  }
}

#  Create a subnet inside your VPC
resource "aws_subnet" "cr_subnet" {
  vpc_id = aws_vpc.coderunner_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true # Enable auto-assign public IP
  tags = {
    Name = "coderunner_subnet"
  }
}

# Create a route table for the VPC
resource "aws_route_table" "cr_rt1" {
  vpc_id = aws_vpc.coderunner_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cr_igw.id
  }

  tags = {
    Name = "cr_rt1"
  }
}

# Associate the route table to the subtnet you created
resource "aws_route_table_association" "cr_a" {
  subnet_id = aws_subnet.cr_subnet.id
  route_table_id = aws_route_table.cr_rt1.id
}

# Create a security group
resource "aws_security_group" "cr_allow_web" {
  name = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id = aws_vpc.coderunner_vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow http from everywhere
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow https from everywhere
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow ssh from everywhere
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"] # allow all outbound traffic to everywhere
  }
  tags = {
    Name = "cr_a"
  }
  
}

# "Import" the key pair you created separately
# resource "aws_key_pair" "coderunner_key" {
#   key_name = "coderunner"
#   public_key = file("${path.module}/coderunner.pub") # replace it with your path and keyname 
# }

# Create the EC2 server
resource "aws_instance" "coderunner_ubuntu" {
    ami = "ami-0fc5d935ebf8bc3bc" # Ubuntu 64-bit
    instance_type = "t2.micro" # need enough memory for pytorch and the ML model
    subnet_id = aws_subnet.cr_subnet.id
    vpc_security_group_ids = [aws_security_group.cr_allow_web.id]
    # key_name =  aws_key_pair.coderunner_key.key_name

     # Specify the size of the root EBS volume
       root_block_device {
        volume_type = "gp2" # General purpose SSD
        volume_size = 20 # Size in GB
    }

    tags = {
      Name = "coderunner_xray_deploy"
    }
}

# Resource for Elastic IP
resource "aws_eip" "coderunner_eip" {
  instance = aws_instance.coderunner_ubuntu.id
  # vpc = true
}
 terraform {
  backend "s3" {
    bucket         = "tf-state-wmill"  # Replace with your bucket name
    key            = "state_file/terraform.tfstate"
    region         = "us-east-1"                  # Replace with your bucket region
    dynamodb_table = "lock_table_tfw"              # Replace with your DynamoDB table name
    encrypt        = true
  }
   
 }



# Associate the elastic IP with your EC2 public IP address
output "public_ip" {
  value = aws_eip.coderunner_eip.public_ip
}