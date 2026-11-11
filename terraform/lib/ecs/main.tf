module "container_images" {
  source = "../images"

  container_image_overrides = var.container_image_overrides
}

locals {
  # Datadog tracer language per service; null = keep built-in OpenTelemetry (Go has no injectable tracer)
  datadog_apm_language = {
    ui       = "java"
    carts    = "java"
    orders   = "java"
    checkout = "js"
    catalog  = null
  }
}
