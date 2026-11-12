################################################################################
# CloudWatch Application Signals (optional, alternative to Datadog):
# ADOT auto-instrumentation injected by an init container + CloudWatch agent
# sidecar with Application Signals enabled (AWS "sidecar strategy" for ECS).
# Java and Node.js get ADOT; other languages (Go) send their own OTLP traces
# to the agent.
################################################################################

locals {
  appsignals_enabled  = var.application_signals.enabled
  appsignals_language = local.appsignals_enabled ? var.application_signals.language : null
  appsignals_injected = local.appsignals_language != null

  appsignals_init = {
    java = {
      image   = "public.ecr.aws/aws-observability/adot-autoinstrumentation-java:${var.application_signals.java_version}"
      command = ["cp", "/javaagent.jar", "/otel-auto-instrumentation/javaagent.jar"]
      env     = { JAVA_TOOL_OPTIONS = " -javaagent:/otel-auto-instrumentation/javaagent.jar" }
    }
    js = {
      image   = "public.ecr.aws/aws-observability/adot-autoinstrumentation-node:${var.application_signals.node_version}"
      command = ["cp", "-a", "/autoinstrumentation/.", "/otel-auto-instrumentation"]
      env     = { NODE_OPTIONS = "--require /otel-auto-instrumentation/autoinstrumentation.js" }
    }
  }

  appsignals_app_environment = !local.appsignals_enabled ? {} : merge(
    {
      OTEL_RESOURCE_ATTRIBUTES           = "service.name=${var.service_name},deployment.environment=${var.application_signals.env},aws.log.group.names=${var.cloudwatch_logs_group_id}"
      OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://localhost:4316/v1/traces"
      OTEL_EXPORTER_OTLP_PROTOCOL        = "http/protobuf"
    },
    local.appsignals_injected ? merge({
      OTEL_AWS_APPLICATION_SIGNALS_ENABLED           = "true"
      OTEL_AWS_APPLICATION_SIGNALS_EXPORTER_ENDPOINT = "http://localhost:4316/v1/metrics"
      OTEL_METRICS_EXPORTER                          = "none"
      OTEL_LOGS_EXPORTER                             = "none"
      OTEL_TRACES_SAMPLER                            = "xray"
      OTEL_TRACES_SAMPLER_ARG                        = "endpoint=http://localhost:2000"
      OTEL_PROPAGATORS                               = "tracecontext,baggage,b3,xray"
    }, local.appsignals_init[local.appsignals_language].env) : {}
  )

  appsignals_mounts = local.appsignals_injected ? [
    { sourceVolume = "otel-auto-instrumentation", containerPath = "/otel-auto-instrumentation", readOnly = false }
  ] : []

  appsignals_containers = jsondecode(!local.appsignals_enabled ? "[]" : jsonencode(concat(
    [{
      name      = "ecs-cwagent"
      image     = "public.ecr.aws/cloudwatch-agent/cloudwatch-agent:latest"
      essential = false
      environment = [{
        name = "CW_CONFIG_CONTENT"
        value = jsonencode({
          traces = { traces_collected = { application_signals = {} } }
          logs   = { metrics_collected = { application_signals = {} } }
        })
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.cloudwatch_logs_group_id
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs-cwagent"
        }
      }
    }],
    local.appsignals_injected ? [{
      name        = "otel-init"
      image       = local.appsignals_init[local.appsignals_language].image
      essential   = false
      command     = local.appsignals_init[local.appsignals_language].command
      mountPoints = local.appsignals_mounts
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.cloudwatch_logs_group_id
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "otel-init"
        }
      }
    }] : []
  )))
}

resource "aws_iam_role_policy_attachment" "appsignals_agent" {
  count      = local.appsignals_enabled ? 1 : 0
  role       = aws_iam_role.task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
