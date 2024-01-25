resource "aws_vpc" "main" {
  cidr_block = "10.16.0.0/16"
}

resource "aws_subnet" "public_subnet_1a" {
 vpc_id     = aws_vpc.main.id
 cidr_block = "10.16.1.0/24"
 availability_zone = "us-east-1a"
 map_public_ip_on_launch = true
 tags = {
   Name = "Public Subnet 1A"
 }
}

resource "aws_subnet" "public_subnet_1b" {
 vpc_id     = aws_vpc.main.id
 cidr_block = "10.16.2.0/24"
 availability_zone = "us-east-1b"
 map_public_ip_on_launch = true
 tags = {
   Name = "Public Subnet 1B"
 }
}


resource "aws_internet_gateway" "igw" {
 vpc_id = aws_vpc.main.id
}

resource "aws_eip" "ngw_gateway_ip" {
    domain = "vpc"
}

resource "aws_nat_gateway" "ngw" {

  # Allocating the Elastic IP to the NAT Gateway!
  allocation_id = aws_eip.ngw_gateway_ip.id

  # Associating it in the Public Subnet!
  subnet_id = aws_subnet.public_subnet_1a.id
}

resource "aws_route_table" "igw_route_table" {
 vpc_id = aws_vpc.main.id

 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.igw.id
 }
}

resource "aws_route_table" "ngw_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

}

resource "aws_route_table_association" "public_subnet_1a" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.igw_route_table.id
}

resource "aws_route_table_association" "public_subnet_1b" {
  subnet_id      = aws_subnet.public_subnet_1b.id
  route_table_id = aws_route_table.igw_route_table.id
}