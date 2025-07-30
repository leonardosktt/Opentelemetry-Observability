variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  type = string
}

variable "environment" {
  description = "AWS environment"
  type        = string
}

variable "prometheus_workspace" {
  description = "AWS environment"
  type        = string
}

variable "log_group" {
  type = string
}

variable "prometheus_endpoint" {
  type = string
}

variable "namespace_observability" {
  type        = string
  description = "Kubernetes namespace"
}

variable "cluster_name" {
  type        = string
  description = "Kubernetes cluster name"
}
