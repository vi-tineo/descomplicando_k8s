variable "instance_type" {
  type = string
}

variable "ami" {
  type = string
}

variable "key_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "vpc_security_group_id" {
  type = list(string)
}

variable "Name" {
  description = "tags"
  type        = string
}