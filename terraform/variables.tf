variable "AWS_REGION" {
  type        = string
  description = "AWS Region"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "name" {
  description = "Name of the EKS managed node group"
  type        = string
  default     = "test"
}

variable "private_subnet_tags" {
  description = "Tags to be applied to private subnet"
  type        = map(string)
  default     = null
}

variable "public_subnet_tags" {
  description = "Tags to be applied to public subnet"
  type        = map(string)
  default     = null
}

variable "environment" {
  description = "Environment name (e.g., prod, dev)"
  type        = string
  default     = "demo"
}

variable "log_retention_in_days" {
  description = "Log retention on cloudwatch in days"
  type        = number
  default     = 3
}

variable "container_insights" {
  description = "Enable container insights?"
  type        = bool
  default     = true
}

variable "service_name" {
  description = "Unique name for the ecs service"
  type        = string
  default     = "demo-exam"
}

variable "container_cpu" {
  type        = number
  description = "CPU allocation for the app."
  default     = 256
}

variable "container_memory" {
  type        = number
  description = "Memory allocation for the app."
  default     = 1024
}

variable "image" {
  type        = string
  description = "image name (image:tag)"
}

variable "container_port" {
  type        = number
  description = "Port number application runs on"
  default     = 3000
}

variable "desired_count" {
  type        = number
  description = "Desired count of the app instances"
  default     = 1
}
