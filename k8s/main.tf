# -------------------------------
# Namespaces
# -------------------------------
resource "kubernetes_namespace" "test_app" {
  metadata {
    name = "test-app"
  }
}


# -------------------------------
# Expose Argo CD via LoadBalancer
# -------------------------------
resource "kubernetes_service" "argocd_server_lb" {
  metadata {
    name      = "argocd-server-lb"
    namespace = "argocd"
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "argocd-server"
    }

    port {
      name        = "https"
      port        = 443
      target_port = 8080
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8080
    }

    # port {
    #   name        = "app"
    #   port        = 8080  # external port for new app
    #   target_port = 30080 # NodePort of new app
    # }

    type = "LoadBalancer"
  }

}

# For this version to work use port forwarding

# -------------------------------
# Frontend Application via Argo CD
# -------------------------------
resource "kubernetes_manifest" "frontend_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "frontend"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/IoanAdafinei/aks-terraform-argocd.git"
        targetRevision = "main"
        path           = "gitops-repo/apps/frontend"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "test-app"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.test_app]
}

# -------------------------------
# Backend Application via Argo CD
# -------------------------------
resource "kubernetes_manifest" "backend_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "backend"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/IoanAdafinei/aks-terraform-argocd.git"
        targetRevision = "main"
        path           = "gitops-repo/apps/backend"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "test-app"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.test_app]
}
