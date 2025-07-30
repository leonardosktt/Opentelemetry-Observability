resource "kubernetes_service_account" "otel_collector_sa" {
  metadata {
    name      = "otel-collector-sa"
    namespace = var.namespace_observability

    labels = {
      "app.kubernetes.io/component"   = "opentelemetry-collector"
      "app.kubernetes.io/instance"    = "opentelemetry.otel-collector"
      "app.kubernetes.io/managed-by"  = "opentelemetry-operator"
      "app.kubernetes.io/name"        = "otel-collector-collector"
      "app.kubernetes.io/part-of"     = "opentelemetry"
      "app.kubernetes.io/version"     = "latest"
    }
    annotations = {
      "<role_arn>"
    }
    
  }
}
