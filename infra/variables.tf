variable "application_name" {
  type = string
}

variable "primary_location" {
  type = string
}

variable "public_key" {
  type = string
}

variable "private_key_path" {
  type = string
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}
