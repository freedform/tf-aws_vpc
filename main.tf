locals {
  name_prefix = var.name_prefix == null ? "" : "${var.name_prefix}_"

  public_subnets_mapping = {
    for i, subnet in var.public_subnets : "subnet_${i}" => subnet
  }
  private_subnets_mapping = {
    for i, subnet in var.private_subnets : "subnet_${i}" => subnet
  }

  az_names = data.aws_availability_zones.azs.names
  public_az_mapping = {
    for i, subnet in var.public_subnets : "subnet_${i}" => element(local.az_names, i % length(local.az_names))
  }
  private_az_mapping = {
    for i, subnet in var.private_subnets : "subnet_${i}" => element(local.az_names, i % length(local.az_names))
  }

  nat_gateway_count = var.nat_gateway_count > 0 ? min(var.nat_gateway_count, length(local.az_names)) : 0
  nat_gateway_subnet_mapping = local.nat_gateway_count > 0 ? {
    for i in range(local.nat_gateway_count) :
    "nat_gw_${i}" => element(keys(local.public_subnets_mapping), i % length(local.public_subnets_mapping))
  } : {}
  private_subnet_nat_mapping = local.nat_gateway_count > 0 ? {
    for i, subnet_key in keys(local.private_subnets_mapping) :
    subnet_key => element(keys(local.nat_gateway_subnet_mapping), i % local.nat_gateway_count)
  } : {}
}

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  tags = merge({
    Name = "${local.name_prefix}vpc"
  }, var.tags)
}

# Public subnets
resource "aws_internet_gateway" "igw" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = merge({
    Name = "${local.name_prefix}igw"
  }, var.tags)
}

resource "aws_subnet" "public_subnet" {
  for_each          = var.create_public_subnets ? local.public_subnets_mapping : {}
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value
  availability_zone = local.public_az_mapping[each.key]
  tags = merge({
    Name = "${local.name_prefix}public_${each.key}"
  }, var.tags)
}

resource "aws_route_table" "public" {
  count  = var.create_public_subnets ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = merge({
    Name = "${local.name_prefix}public_route_table"
  }, var.tags)
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
  depends_on             = [aws_internet_gateway.igw, aws_route_table.public]
}

# Private subnets
resource "aws_subnet" "private_subnet" {
  for_each          = var.create_private_subnets ? local.private_subnets_mapping : {}
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value
  availability_zone = local.private_az_mapping[each.key]
  tags = merge({
    Name = "${local.name_prefix}private_${each.key}"
  }, var.tags)
}

resource "aws_route_table" "private" {
  for_each = var.create_private_subnets ? local.private_subnets_mapping : {}
  vpc_id   = aws_vpc.vpc.id
  tags = merge({
    Name = "${local.name_prefix}${replace(each.key, "subnet", "private_route_table")}"
  }, var.tags)
}

resource "aws_route_table_association" "private_association" {
  for_each       = var.create_private_subnets ? local.private_subnets_mapping : {}
  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_eip" "eip" {
  for_each = local.nat_gateway_subnet_mapping
  tags = merge({
    Name = "${local.name_prefix}${each.key}_eip"
  }, var.tags)
}

resource "aws_nat_gateway" "nat_gw" {
  for_each      = local.nat_gateway_subnet_mapping
  allocation_id = aws_eip.eip[each.key].id
  subnet_id     = aws_subnet.public_subnet[each.value].id
  depends_on    = [aws_internet_gateway.igw]
  tags = merge({
    Name = "${local.name_prefix}${each.key}"
  }, var.tags)
}

resource "aws_route" "nat_route" {
  for_each               = local.nat_gateway_count > 0 ? local.private_subnets_mapping : {}
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[local.private_subnet_nat_mapping[each.key]].id
  depends_on             = [aws_nat_gateway.nat_gw]
}
