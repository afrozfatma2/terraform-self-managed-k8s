variable "region" {
  default = "ap-south-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "key_name" {
  description = "jenkins-server-key"
}

variable "vpc_id" {
  default = "default"
}

variable "subnet_id" {
  description = "Subnet where EC2 will be created"
}
