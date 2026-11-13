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

  # Image ENTRYPOINTs (src/*/Dockerfile), restated for the Workload Protection ptrace wrapper
  app_entry_point = {
    ui       = ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
    carts    = ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
    orders   = ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
    checkout = ["node", "dist/main.js"]
    catalog  = ["/app/main"]
  }
}
