################################################################################
# Security log sources for Datadog Cloud SIEM:
#   CloudTrail (management events, all regions), ALB access logs and VPC Flow Logs
#   land in one S3 bucket; the Datadog Forwarder Lambda ships each new object to Datadog.
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  bucket_name = "${var.environment_name}-security-logs-${local.account_id}"
  # Elastic Load Balancing log-delivery account for eu-west-3 (Paris)
  elb_account_ids = { "eu-west-3" = "009996457667", "eu-west-1" = "156460612806", "us-east-1" = "127311923021" }
}

resource "aws_s3_bucket" "logs" {
  bucket        = local.bucket_name
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ALB access logs only support SSE-S3
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire"
    status = "Enabled"
    filter {}
    expiration { days = var.retention_days }
  }
}

data "aws_iam_policy_document" "logs" {
  statement {
    sid       = "CloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.logs.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${local.region}:${local.account_id}:trail/${var.environment_name}-trail"]
    }
  }
  statement {
    sid       = "CloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/cloudtrail/AWSLogs/${local.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${local.region}:${local.account_id}:trail/${var.environment_name}-trail"]
    }
  }
  statement {
    sid       = "AlbAccessLogs"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/alb/AWSLogs/${local.account_id}/*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${local.elb_account_ids[local.region]}:root"]
    }
  }
  statement {
    sid       = "FlowLogsAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.logs.arn]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
  statement {
    sid       = "FlowLogsWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/vpcflowlogs/AWSLogs/${local.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket     = aws_s3_bucket.logs.id
  policy     = data.aws_iam_policy_document.logs.json
  depends_on = [aws_s3_bucket_public_access_block.logs]
}

# --- CloudTrail: management events from every region ---
resource "aws_cloudtrail" "this" {
  name                          = "${var.environment_name}-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  s3_key_prefix                 = "cloudtrail"
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  tags                          = var.tags

  depends_on = [aws_s3_bucket_policy.logs]
}

# --- VPC Flow Logs ---
resource "aws_flow_log" "vpc" {
  vpc_id                   = var.vpc_id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = "${aws_s3_bucket.logs.arn}/vpcflowlogs"
  max_aggregation_interval = 60
  tags                     = var.tags

  depends_on = [aws_s3_bucket_policy.logs]
}

# --- Datadog Forwarder (official CloudFormation template) ---
resource "aws_cloudformation_stack" "forwarder" {
  name         = "${var.environment_name}-datadog-forwarder"
  template_url = "https://datadog-cloudformation-template.s3.amazonaws.com/aws/forwarder/latest.yaml"
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM", "CAPABILITY_AUTO_EXPAND"]

  parameters = {
    DdApiKey          = "USE_ARN"
    DdApiKeySecretArn = var.datadog_api_key_secret_arn
    DdSite            = var.datadog_site
    FunctionName      = "${var.environment_name}-datadog-forwarder"
    DdTags            = "env:${var.datadog_env},app:retail-store"
  }

  tags = var.tags

  lifecycle {
    # The template URL is "latest"; do not redeploy on every plan
    ignore_changes = [template_url]
  }
}

resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_cloudformation_stack.forwarder.outputs["DatadogForwarderArn"]
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.logs.arn
}

resource "aws_s3_bucket_notification" "logs" {
  bucket = aws_s3_bucket.logs.id
  lambda_function {
    lambda_function_arn = aws_cloudformation_stack.forwarder.outputs["DatadogForwarderArn"]
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.s3]
}
