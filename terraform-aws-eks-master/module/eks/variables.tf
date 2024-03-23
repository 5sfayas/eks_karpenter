# variable "availability_zones" {
#   default = ""
# }

variable "environment" {
  default = ""  
}

variable "cluster_name" {
  default = ""
}

variable "subnet_id" {
  default = [""]
  type    = list(string) 
}