variable "environment_name" {
  type        = string
  description = "Name of the environment"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the resources"
}

variable "subnet_ids" {
  description = "List of subnet IDs used by database subnet group created"
  type        = list(string)
}

variable "tags" {
  description = "List of tags to be associated with resources."
  default     = {}
  type        = any
}

variable "catalog_security_group_id" {
  type        = string
  description = "Security group ID of the catalog component"
}

variable "orders_security_group_id" {
  type        = string
  description = "Security group ID of the orders component"
}

variable "checkout_security_group_id" {
  type        = string
  description = "Security group ID of the checkout component"
}

variable "allowed_security_group_ids" {
  type        = list(string)
  default     = []
  description = "List of additional allowed security group IDs"
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
