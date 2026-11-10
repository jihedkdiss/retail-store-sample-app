variable "environment_name" {
  type        = string
  default     = "retail-store-ecs"
  description = "Name of the environment"
}

variable "container_image_overrides" {
  type = object({
    default_repository = optional(string)
    default_tag        = optional(string)

    ui       = optional(string)
    catalog  = optional(string)
    cart     = optional(string)
    checkout = optional(string)
    orders   = optional(string)
  })
  default     = {}
  description = "Object that encapsulates any overrides to default values"
}

variable "opentelemetry_enabled" {
  type        = bool
  default     = false
  description = "Boolean value that enables OpenTelemetry."
}

variable "container_insights_setting" {
  type        = string
  default     = "enhanced"
  description = "Container Insights setting for ECS cluster (enhanced or disabled)"

  validation {
    condition     = contains(["enhanced", "disabled"], var.container_insights_setting)
    error_message = "container_insights_setting must be either 'enhanced' or 'disabled'"
  }
}

variable "lifecycle_events_enabled" {
  type        = bool
  default     = false
  description = "Enable ECS lifecycle events to CloudWatch Logs"

  validation {
    condition     = !var.lifecycle_events_enabled || var.container_insights_setting == "enhanced"
    error_message = "lifecycle_events_enabled can only be true when container_insights_setting is 'enhanced'"
  }
}
variable "task_cpu" {
  type        = string
  default     = "1024"
  description = "Fargate task CPU units for every service"
}

variable "task_memory" {
  type        = string
  default     = "2048"
  description = "Fargate task memory (MiB) for every service"
}

variable "mq_instance_type" {
  type        = string
  default     = "mq.m5.large"
  description = "Amazon MQ broker instance type"
}

variable "opensearch_instance_type" {
  type        = string
  default     = "r8g.medium.search"
  description = "OpenSearch data node instance type"
}

variable "opensearch_volume_size" {
  type        = number
  default     = 50
  description = "OpenSearch EBS volume size (GiB)"
}

variable "rds_instance_class" {
  type        = string
  default     = "db.t3.medium"
  description = "Instance class for the catalog and orders Aurora clusters"
}

variable "aws_region" {
  type        = string
  default     = "eu-west-3"
  description = "AWS region to deploy into"
}
