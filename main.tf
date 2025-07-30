/*----------LOG GROUP-----------*/
resource "aws_cloudwatch_log_group" "log_group" {
  name              = ""
  retention_in_days = 60
}

/*----------PROMETHEUS-----------*/
resource "aws_prometheus_workspace" "prometheus" {
  alias = var.prometheus_workspace
}

/*----------GRAFANA-----------*/
resource "aws_grafana_workspace" "grafana" {
  name                      = "grafana-workspace-${var.environment}"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
    configuration = jsonencode(
    {
      "plugins" = {
        "pluginAdminEnabled" = true
      },
      "unifiedAlerting" = {
        "enabled" = false
      }
    }
  )

  data_sources = [
    "CLOUDWATCH",
    "XRAY",
    "PROMETHEUS"
  ]

  role_arn = aws_iam_role.grafana_service_role.arn
}

resource "aws_iam_role" "grafana_service_role" {
  name = "grafana-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "grafana.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "grafana_amp_custom_policy" {
  name        = "GrafanaAMPFullAccessCustom"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:ListWorkspaces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "aps:DescribeWorkspace",
          "aps:GetLabels",
          "aps:GetMetricMetadata",
          "aps:GetSeries",
          "aps:QueryMetrics",
          "xray:*",
          "ec2:DescribeRegions",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "otel_operator" {
  name = "otel-operator-role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = ""
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          ""
        }
      }
    }]
  })

  inline_policy {
    name = "otel-operator-policy"

    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords",
            "xray:GetSamplingRules",
            "xray:GetSamplingTargets",
            "xray:GetSamplingStatisticSummaries"
          ],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = [
            "logs:PutLogEvents",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:DescribeLogStreams",
            "logs:DescribeLogGroups"
          ],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = [
            "aps:RemoteWrite",
            "aps:GetSeries",
            "aps:GetLabels",
            "aps:GetMetricMetadata"
          ],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = [
            "ssm:GetParameters",
            "ec2:DescribeTags",
            "ecs:DescribeClusters",
            "ecs:ListClusters",
            "ecs:DescribeTasks",
            "ecs:ListTasks"
          ],
          Resource = "*"
        }
      ]
    })
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "attach_grafana_amp_custom_policy" {
  role       = aws_iam_role.grafana_service_role.name
  policy_arn = aws_iam_policy.grafana_amp_custom_policy.arn
}
resource "aws_iam_role_policy_attachment" "grafana_admin_policy" {
  role       = aws_iam_role.grafana_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSGrafanaAccountAdministrator"
}


resource "aws_iam_role" "otel_collector" {
  name = "otel-collector-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.eks.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace_observability}:otel-collector-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "otel_collector_policy" {
  name = "otel-collector-policy"
  role = aws_iam_role.otel_collector.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "aps:RemoteWrite"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "kubernetes_cluster_role" "otel_collector_k8s_read" {
  metadata {
    name = "otel-collector-k8s-read"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "otel_collector_k8s_read" {
  metadata {
    name = "otel-collector-k8s-read"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.otel_collector_k8s_read.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "otel-collector-sa"
    namespace = "opentelemetry"
  }
}
