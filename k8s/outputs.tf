output "argocd_server_ip" {
  value       = kubernetes_service.argocd_server_lb.status[0].load_balancer[0].ingress[0].ip
  description = "External IP of the Argo CD LoadBalancer"
}
