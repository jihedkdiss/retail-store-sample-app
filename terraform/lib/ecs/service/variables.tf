variable "environment_name" {
  type        = string
  description = "Name of the environment"
}

variable "service_name" {
  type        = string
  description = "Name of the ECS service"
}

variable "cluster_arn" {
  description = "ECS cluster ARN"
  type        = string
}

variable "tags" {
  description = "List of tags to be associated with resources."
  default     = {}
  type        = any
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs."
  type        = list(string)
}

variable "container_image" {
  description = "Container image for the service"
  type        = string
}

variable "service_discovery_namespace_arn" {
  description = "ARN of the service discovery namespace for Service Connect"
  type        = string
}

variable "environment_variables" {
  description = "Map of environment variables for the ECS task"
  default     = {}
  type        = any
}

variable "secrets" {
  description = "Map of secrets for the ECS task"
  default     = {}
  type        = any
}

variable "additional_task_role_iam_policy_arns" {
  description = "Additional IAM policy ARNs to be added to the task role"
  default     = []
  type        = list(string)
}

variable "additional_task_execution_role_iam_policy_arns" {
  description = "Additional IAM policy ARNs to be added to the task execution role"
  default     = []
  type        = list(string)
}

variable "healthcheck_path" {
  description = "HTTP path used to health check the service"
  default     = "/health"
  type        = string
}

variable "cloudwatch_logs_group_id" {
  description = "CloudWatch logs group ID"
  type        = string
}

variable "alb_target_group_arn" {
  description = "ARN of the ALB target group the ECS service should register tasks to"
  default     = ""
  type        = string
}

variable "opentelemetry_enabled" {
  description = "Boolean value that enables OpenTelemetry."
  type        = bool
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  default     = "1024"
  type        = string
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  default     = "2048"
  type        = string
}

variable "datadog" {
  description = <<-EOT
    Datadog instrumentation for this service. When enabled, the task definition is built by
    Datadog's ecs_fargate module (Agent sidecar, optional tracer injection and FireLens logs)
    instead of the upstream definition, and the CloudWatch agent sidecar is not used.
      - apm_language: "java" or "js" injects the Datadog tracer; null keeps the app's
        built-in OpenTelemetry and sends OTLP to the Agent instead (e.g. Go).
  EOT
  type = object({
    enabled            = bool
    site               = optional(string, "datadoghq.com")
    api_key_secret_arn = optional(string)
    env                = optional(string, "dev")
    apm_language       = optional(string)
    appsec_enabled     = optional(bool, false)
    logs_enabled       = optional(bool, false)
  })
  default = { enabled = false }

  validation {
    condition     = !var.datadog.enabled || var.datadog.api_key_secret_arn != null
    error_message = "datadog.api_key_secret_arn is required when datadog.enabled is true."
  }

  validation {
    condition     = var.datadog.apm_language == null || contains(["java", "js"], coalesce(var.datadog.apm_language, "none"))
    error_message = "datadog.apm_language must be \"java\", \"js\" or null."
  }
}
