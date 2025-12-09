variable "region" {
  default = "ap-south-1"
}

variable "instance_type" {
  default = "t3.small"
}

variable "key_name" {
  default = "jenkins-server-key"
}

variable "vpc_id" {
  default = "default"
}

variable "subnet_id" {
  default  = "subnet-00f2a35e44ae717e3"
}

#