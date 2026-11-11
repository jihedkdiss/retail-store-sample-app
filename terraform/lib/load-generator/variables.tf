variable "environment_name" {
  type        = string
  description = "Name of the environment"
}

variable "cluster_arn" {
  type        = string
  description = "ECS cluster to run the load generator in"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnets (outbound via NAT)"
}

variable "target_url" {
  type        = string
  description = "Base URL of the UI, e.g. the ALB URL"
}

variable "users_per_minute" {
  type        = number
  default     = 6
  description = "Virtual users (full shop journeys) started per minute"
}

variable "app_version" {
  type        = string
  default     = "1.6.3"
  description = "Tag of the retail-store-sample-utils load-gen image (match the app version)"
}

variable "artillery_version" {
  type        = string
  default     = "2.0.22"
  description = "Artillery image tag"
}

variable "tags" {
  type        = any
  default     = {}
  description = "Tags to apply to resources"
}
