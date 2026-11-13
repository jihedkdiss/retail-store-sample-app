output "bucket_name" {
  value = aws_s3_bucket.logs.id
}

output "alb_access_logs" {
  description = "Value for the ALB module's access_logs argument"
  value       = { bucket = aws_s3_bucket.logs.id, prefix = "alb", enabled = true }
  # ELB checks write access when logging is enabled
  depends_on = [aws_s3_bucket_policy.logs]
}

output "forwarder_arn" {
  value = aws_cloudformation_stack.forwarder.outputs["DatadogForwarderArn"]
}
