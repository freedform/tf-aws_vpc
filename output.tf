output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnets" {
  value = [
    for object in values(aws_subnet.public_subnet) : object.id
  ]
}

output "private_subnets" {
  value = [
    for object in values(aws_subnet.private_subnet) : object.id
  ]
}

output "public_cidr_blocks" {
  value = [
    for object in values(aws_subnet.public_subnet) : object.cidr_block
  ]
}

output "private_cidr_blocks" {
  value = [
    for object in values(aws_subnet.private_subnet) : object.cidr_block
  ]
}

output "public_route_tables" {
  value = aws_route_table.public[*].id
}

output "private_route_tables" {
  value = [
    for object in values(aws_route_table.private) : object.id
  ]
}