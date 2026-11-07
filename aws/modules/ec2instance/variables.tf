variable "name" {
  default     = "this"
  description = "identifier for a lot of resources"
}
variable "ssh_public_key" {
  description = "ssh public key"
  default     = ""
  type        = string
}
variable "ec2_ami_id" {
  default     = null
  description = "(Optional) - id of the ami"
}
variable "ami_name_pattern" {
  description = "pattern for ami name"
  type        = string
  default     = ""
}
variable "ami_owner" {
  default     = "099720109477" # canonical
  description = "ami owner to limit search"
}
variable "instance_type" {
  description = "ec2 instance type"
  type        = string
  default     = "t3.micro"
}
variable "vpc_id" {
  description = "id of the vpc"
  type        = string
}
variable "subnet_id" {
  description = "id of the subnet, overrides random chosen one from subnet_ids"
  type        = string
  default     = ""
}
variable "subnet_ids" {
  description = "list of subnet ids, one subnet_id is chosen per random"
  type = list(string)
  default = []
}
variable "route53_public_hostedzone_id" {
  default     = ""
  description = "Route53 Zone ID for public hosted zone"
}
variable "route53_private_hostedzone_id" {
  default     = ""
  description = "Route53 Zone ID for private hosted zone"
}
variable "firewall_rules" {
  type        = list(map(string))
  description = "list of firewall rules"
  default     = []
}
variable "dns_name" {
  default     = null
  description = "override generated dns name"
}
variable "ec2_role_policy_attachments" {
  type        = list(string)
  default     = []
  description = "iam policy attachments for ec2 role"
}
variable "user_data" {
  type        = string
  default     = null
  description = "User data to provide when launching the instance."
}
variable "volume_size" {
  type        = number
  default     = 50
  description = "Size of the volume in gibabytes (GiB)"
}
variable "volume_tags" {
  default     = {}
  type        = map(any)
  description = "ec2 volume_tags"
}

variable "ec2_tags" {
  default     = {}
  type        = map(any)
  description = "additional ec2 tags"
}

variable "availability_zone" {
  default = "eu-central-1c"
  type = string
  description = "availability_zone"
}
