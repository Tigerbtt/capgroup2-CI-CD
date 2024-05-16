# Declare a variable so we can use it.
variable "region" {
  default = "us-west-2"
  type    = string
}

variable "config_user_alias" {
  type        = string
  description = "Your student alias"
}

variable "github" {
  type = string
  description = "Github repository"
}

variable "port"{
  type = number
  description = "Port number for the servce"
  default = 80
}