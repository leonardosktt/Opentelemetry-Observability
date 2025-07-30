resource "kubernetes_manifest" "otel_collector" {
  manifest = {
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "OpenTelemetryCollector"
    metadata = {
      name      = "otel-collector"
      namespace = "opentelemetry"
    }
    spec = {
      mode            = "deployment"
      serviceAccount  = "otel-collector-sa"
      image           = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      imagePullPolicy = "Always"
      replicas        = 3
      config = <<-EOT
        receivers:
          otlp:
            protocols:
              grpc:
              http:
          prometheus:
            config:
              scrape_configs:
                - job_name: 'k8s-apps'
                  kubernetes_sd_configs:
                    - role: endpoints
                  relabel_configs:
                    - source_labels: [__meta_kubernetes_service_label_metrics]
                      action: keep
                      regex: true
                    - source_labels: [__meta_kubernetes_endpoint_port_name]
                      action: keep
                      regex: http
                  metrics_path: /q/metrics
                  scheme: http

        processors:
          batch: {}
          filter/ottl:
            error_mode: ignore
            traces:
              span:
                - 'attributes["http.route"] == "/q/health"'
                - 'attributes["http.route"] == "/q/health/ready"'
                - 'attributes["http.route"] == "/q/health/live"'
                - 'attributes["url.path"] == "/q/health"'
                - 'attributes["url.path"] == "/q/health/ready"'
                - 'attributes["url.path"] == "/q/health/live"'
                - 'attributes["url.path"] == "/healthz"'
                - 'attributes["url.path"] == "/readyz"'

        exporters:
          awsxray:
            region: us-east-1
          prometheus:
            endpoint: "0.0.0.0:8889"
          prometheusremotewrite:
            endpoint: ${var.prometheus_endpoint}
            auth:
              authenticator: sigv4auth
          awsemf:
            region: us-east-1
          awscloudwatchlogs:
            region: us-east-1
            log_group_name: <name-log-group>
            log_stream_name: "otel-app-collector-logs"

        extensions:
          sigv4auth:
            region: us-east-1
            service: aps

        service:
          telemetry:
            logs:
              level: info
          extensions: [sigv4auth]
          pipelines:
            traces:
              receivers: [otlp]
              processors: [filter/ottl, batch]
              exporters: [awsxray]
            metrics:
              receivers: [otlp, prometheus]
              processors: [batch]
              exporters: [prometheus, awsemf, prometheusremotewrite]
            logs:
              receivers: [otlp]
              processors: [batch]
              exporters: [awscloudwatchlogs]
      EOT
    }
  }
}
