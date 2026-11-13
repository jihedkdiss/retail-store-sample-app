variable "environment_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vpc_id" {
  description = "VPC whose traffic is captured with Flow Logs"
  type        = string
}

variable "retention_days" {
  description = "Days to keep raw log files in S3 (Datadog keeps its own copy)"
  type        = number
  default     = 7
}

variable "datadog_api_key_secret_arn" {
  description = "Secrets Manager secret holding the Datadog API key (plain string)"
  type        = string
}

variable "datadog_site" {
  type    = string
  default = "datadoghq.com"
}

variable "datadog_env" {
  type    = string
  default = "dev"
}
