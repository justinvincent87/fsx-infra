variable "name"         { type = string }
variable "vpc_cidr"     { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "azs"          { type = list(string) }
variable "nat_count"    { type = list(number) } # indices mapping to public subnet index for NATs
variable "tags"         { type = map(string) }
variable "region"       { type = string }
