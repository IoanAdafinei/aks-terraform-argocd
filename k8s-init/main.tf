# -------------------------------
# Install Argo CD via kubectl
# -------------------------------
resource "null_resource" "install_argocd" {

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_file
    }

    command = <<EOT
      echo "Installing Argo CD..."
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
      curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml | kubectl apply -n argocd -f -
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

# -------------------------------
# Wait for Argo CD CRDs to be ready
# -------------------------------
resource "null_resource" "wait_for_argocd_crds" {
  depends_on = [null_resource.install_argocd]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_file
    }

    interpreter = ["bash", "-c"]
    command     = <<EOT
echo "Waiting for Argo CD CRDs..."
timeout=300
start=$(date +%s)
while ! kubectl get crd applications.argoproj.io >/dev/null 2>&1; do
  sleep 5
  now=$(date +%s)
  if [ $((now - start)) -ge $timeout ]; then
    echo "Timeout waiting for Argo CRDs"
    exit 1
  fi
done
echo "Argo CD CRDs ready!"
EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

