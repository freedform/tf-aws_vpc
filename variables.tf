variable "create_vpc" {
  description = "Controls VPC creation"
  type        = bool
  default     = true
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "create_public_subnets" {
  description = "Controls public subnets creation"
  type        = bool
  default     = true
}

variable "public_subnets" {
  description = "List of public subnets"
  type        = list(string)
  default     = []
}

variable "create_private_subnets" {
  description = "Controls private subnets creation"
  type        = bool
  default     = true
}

variable "private_subnets" {
  description = "List of private subnets"
  type        = list(string)
  default     = []
}

variable "create_nat_gateway" {
  description = "Controls creation of NAT gateway"
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "Name prefix for created object"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags that are assigned to network objects"
  type        = object({})
  default     = {}
}