terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    http = {
      source = "hashicorp/http"
    }
  }
}


# Kubernetes provider using AKS kubeconfig
provider "kubernetes" {
  config_path = var.kubeconfig_file
}
