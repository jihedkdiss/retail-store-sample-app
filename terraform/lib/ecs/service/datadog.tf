################################################################################
# Datadog (optional): Agent sidecar, APM tracer injection, App & API Protection,
# FireLens log shipping. Only used when var.datadog.enabled is true.
################################################################################

locals {
  datadog_tracer_injected = var.datadog.enabled && var.datadog.apm_language != null
  workload_protection     = var.datadog.enabled && var.datadog.workload_protection_enabled && var.datadog.entry_point != null

  # Use the app's built-in OpenTelemetry when explicitly enabled (upstream behaviour)
  # or when Datadog is on but no Datadog tracer can be injected (Go).
  otel_enabled = var.opentelemetry_enabled || (var.datadog.enabled && !local.datadog_tracer_injected) || (var.application_signals.enabled && var.application_signals.language == null)

  image_tag    = element(split(":", var.container_image), length(split(":", var.container_image)) - 1)
  cluster_name = element(split("/", var.cluster_arn), length(split("/", var.cluster_arn)) - 1)

  datadog_app_environment = !var.datadog.enabled ? {} : merge(
    # Keep a single tracer per process: the Node service starts its OTel SDK unconditionally.
    local.datadog_tracer_injected ? { OTEL_SDK_DISABLED = "true" } : {},
    local.datadog_tracer_injected && var.datadog.appsec_enabled ? { DD_APPSEC_ENABLED = "true" } : {},
    # Runtime Code Analysis (IAST): Java >= 1.15 / Node dd-trace >= 5.0; not available for Go.
    local.datadog_tracer_injected && var.datadog.iast_enabled ? { DD_IAST_ENABLED = "true" } : {},
    # OTel-instrumented services: give spans the same env/version tags as the DD tracer.
    local.datadog_tracer_injected ? {} : {
      OTEL_RESOURCE_ATTRIBUTES = "deployment.environment.name=${var.datadog.env},deployment.environment=${var.datadog.env},service.version=${local.image_tag}"
    }
  )
}

module "datadog_task_definition" {
  count = var.datadog.enabled ? 1 : 0

  # Pinned to an unreleased commit on main: tracer injection (dd_apm_instrumentation, PR #93)
  # is not in the latest release (v1.2.2). Switch to a registry version once it is released.
  source = "git::https://github.com/DataDog/terraform-aws-ecs-datadog.git//modules/ecs_fargate?ref=d427422ba4a31486b325bd8387552c7359470b75"

  family                   = "${var.environment_name}-${var.service_name}"
  container_definitions    = jsonencode(local.containers)
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  pid_mode                 = "task"

  execution_role = { arn = aws_iam_role.task_execution_role.arn }
  task_role      = { arn = aws_iam_role.task_role.arn }

  dd_api_key_secret = { arn = var.datadog.api_key_secret_arn }
  dd_site           = var.datadog.site
  dd_service        = var.service_name
  dd_env            = var.datadog.env
  dd_version        = local.image_tag
  dd_cluster_name   = local.cluster_name
  dd_tags           = "app:retail-store"

  dd_apm = { enabled = true }

  # Workload Protection (CWS) on Fargate: eBPF-less, ptrace wrapper on each container entryPoint.
  # The module requires the app containers to wait for a healthy Agent in this mode.
  dd_cws                           = { enabled = local.workload_protection }
  dd_is_datadog_dependency_enabled = local.workload_protection

  dd_apm_instrumentation = local.datadog_tracer_injected ? {
    language       = var.datadog.apm_language
    container_name = "${var.service_name}-service"
  } : null

  # Receive OTLP/HTTP on localhost:4318 for services that use OpenTelemetry.
  dd_environment = local.datadog_tracer_injected ? [] : [
    { name = "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT", value = "0.0.0.0:4318" },
  ]

  dd_log_collection = {
    enabled = var.datadog.logs_enabled
    fluentbit_config = {
      log_driver_configuration = {
        host_endpoint = "http-intake.logs.${var.datadog.site}"
        tls           = true
        compress      = "gzip"
        service_name  = var.service_name
        source_name   = var.service_name
      }
    }
  }

  tags = var.tags
}
