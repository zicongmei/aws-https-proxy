
variable "username" {
  description = "proxy user name"
  type        = string
  default     = "admin"
}

variable "password" {
  description = "proxy password"
  type        = string
  default     = ""
}

variable "input_ip" {
  description = "input ip"
  type        = string
  default     = "0.0.0.0/0"
}