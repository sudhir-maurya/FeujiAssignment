module "label_vpc" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "vpc"
  attributes = ["main"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = module.label_vpc.tags
}

# =========================
# Create your subnets here
# =========================

data "aws_availability_zones" "available" {
  state = "available"
}



# Include the subnets/cidr module to calculate CIDR blocks for the subnets
module "subnets" {
  source = "hashicorp/subnets/cidr"
  version = "1.0.0"
  base_cidr_block = var.vpc_cidr
  networks = [
        {
            name = "public"
            new_bits = 24 - tonumber(split("/", var.vpc_cidr)[1])
        },
        {
            name = "private"
            new_bits = 24 - tonumber(split("/", var.vpc_cidr)[1])
        }
    ]
}

# Create an internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = module.label_vpc.tags
}

# Create a route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = module.label_vpc.tags

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Create the public subnet
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  cidr_block = cidr_block = module.subnets.network_cidr_blocks.public  # First subnet CIDR
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = module.label_vpc.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Create the private subnet
resource "aws_subnet" "private" {
  vpc_id = aws_vpc.main.id
  cidr_block = cidr_block = module.subnets.network_cidr_blocks.private  # Second subnet CIDR
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = module.label_vpc.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

