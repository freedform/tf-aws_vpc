locals {
  public_subnets_mapping = {
    for i, subnet in var.public_subnets : "subnet_${i}" => subnet
  }
  private_subnets_mapping = {
    for i, subnet in var.private_subnets : "subnet_${i}" => subnet
  }
  public_az_mapping = {
    for i, subnet in var.public_subnets : "subnet_${i}" => data.aws_availability_zones.azs.names[i]
  }
  private_az_mapping = {
    for i, subnet in var.private_subnets : "subnet_${i}" => data.aws_availability_zones.azs.names[i]
  }

}

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
}

# Public subnets
resource "aws_internet_gateway" "igw" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "public_subnet" {
  for_each          = var.create_public_subnets ? local.public_subnets_mapping : {}
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value
  availability_zone = local.public_az_mapping[each.key]
}

resource "aws_route_table" "public" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "public_association" {
  for_each       = var.create_public_subnets ? local.public_subnets_mapping : {}
  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route" "igw_route" {
  count                  = var.create_public_subnets ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[0].id
}

# Private subnets
resource "aws_subnet" "private_subnet" {
  for_each          = var.create_private_subnets ? local.private_subnets_mapping : {}
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value
  availability_zone = local.private_az_mapping[each.key]
}

resource "aws_route_table" "private" {
  for_each = var.create_private_subnets ? local.private_subnets_mapping : {}
  vpc_id   = aws_vpc.vpc.id
}

resource "aws_route_table_association" "private_association" {
  for_each       = var.create_private_subnets ? local.private_subnets_mapping : {}
  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_eip" "eip" {
  for_each = var.create_nat_gateway ? local.private_subnets_mapping : {}
}

resource "aws_nat_gateway" "nat_gw" {
  for_each      = var.create_nat_gateway ? local.private_subnets_mapping : {}
  allocation_id = aws_eip.eip[each.key].id
  subnet_id     = aws_subnet.public_subnet[each.key].id
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route" "nat_route" {
  for_each               = var.create_nat_gateway ? local.private_subnets_mapping : {}
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.nat_gw[each.key].id
}