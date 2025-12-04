output "admin_vm_public_ip" {
  value = azurerm_public_ip.vm1-pip.ip_address
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_rg" {
  value = azurerm_resource_group.main.name
}

output "aks_kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config[0]
  sensitive = true
}

locals {
  aks          = azurerm_kubernetes_cluster.aks.kube_config[0]
  cluster_name = azurerm_kubernetes_cluster.aks.name
}

resource "local_file" "aks_kubeconfig_yaml" {
  filename = "${path.module}/aks_kubeconfig.yaml"
  content = yamlencode({
    apiVersion : "v1"
    kind : "Config"
    clusters : [{
      cluster : {
        server : local.aks.host
        "certificate-authority-data" : local.aks.cluster_ca_certificate
      }
      name : local.cluster_name
    }]
    contexts : [{
      context : {
        cluster : local.cluster_name
        user : local.cluster_name
      }
      name : local.cluster_name
    }]
    current-context : local.cluster_name
    users : [{
      name : local.cluster_name
      user : {
        "client-certificate-data" : local.aks.client_certificate
        "client-key-data" : local.aks.client_key
      }
    }]
  })
}

output "kubeconfig_file" {
  value = local_file.aks_kubeconfig_yaml.filename
}
