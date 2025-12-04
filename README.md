
# AKS deployment using terraform and ArgoCD

![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white) 
![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)
![ArgoCD](https://img.shields.io/badge/argo-%23EF7B4D.svg?style=for-the-badge&logo=argo&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)

> This is a simple example of deploying an application using **AKS** as infrastructure and **ArgoCD** to manage the Kubernetes state, all provisioned using **Terraform**. 
>
> The focus of this repo is not the application itself; the app is a minimal frontend and backend, containerized using Docker and pushed to DockerHub.

## 🏗 Architecture


This project demonstrates a GitOps workflow:
```text
    1.  Terraform provisions the Azure resource group, VNet, and AKS Cluster.
    2.  Terraform bootstraps ArgoCD onto the cluster.
    3.  ArgoCD watches this repository and syncs the Kubernetes manifests to deploy the Frontend and Backend applications.
```
## 📂 Project Structure

```text
aks-terraform-argocd/
├── gitops-repo/apps       # Kubernetes manifests (ArgoCD watches this)
|   ├── backend
|   |   ├── backend-deployment.yaml
|   |   └── backend-service.yaml
|   └── frontend
|       ├── backend-deployment.yaml
|       └── backend-service.yaml
|── infra/                 # terraform configuration for Azure infrastructure
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars   # !! you will create this file as it contains sensitive data
│   ├── variables.tf
│   └── versions.tf
├── k8s-init/              # terraform configuration for ArgoCD initialization
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   ├── variables.tf
│   └── versions.tf
├── k8s/                   # terraform configuration for ArgoCD deployed applications
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   ├── variables.tf
│   └── versions.tf
├── .gitignore
└── README.md
```

## 🚀 Prerequisites
Make sure you have the following tools installed:

 - [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

 - [Terraform](https://developer.hashicorp.com/terraform/install)

## 🛠️ Deployment Guide

This guide is for **Linux/Unix**, but it can be used on Windows as well with small adjustments.
1. Clone the repository
```
git clone https://github.com/IoanAdafinei/aks-terraform-argocd.git
cd aks-terraform-argocd/
```
2. Login to Azure
```
az login --use-device-code
```
Note that after you login you will be asked to select the correct subscription. You will need to copy the corresponding Subscription ID and paste it below.
```
echo 'export TF_VAR_subscription_id="<your-subscription-id>"' > ~/.bash_rc
```
3. Prepare the infrastructure
This will create a few resources, but the main ones for now are the resource group, the place where all the resources from this deployment live, the AKS (Azure Kubernetes Service) and the KUBE-ADM VM, the place from where we will run kubectl commands. You can check the rest of the resources from the Portal.
```
cd infra/
```
Make sure you have a ssh key pair on hand. If not you can create a pair using the following command:
```
ssh-keygen -t ed25519 -C "your_email@example.com"
```
You need to follow the prompts and remember where you stored the key pair.

Now create the **terraform.tfvars** file here, with the following content:
```
application_name = "test-app"   # Rename this to whatever you like. This will be used when terraform creates the Azure resources
primary_location = "westeurope" # You can choose whatever region is closest to you (for lower latency), but since this is a learning environment I recommend the cheapest region
public_key       = ""           # The actual public key (the contnent). This will be used to login into the VM 
private_key_path = ""           # Path to the matching private key, used to connect to the VM and prepare the environment
```
At this point we can start the resource provisioning.
```
terraform init  # This will initialize all the necessary packages
terraform plan  # This will present a plan of what changes terraform will do
terraform apply # This will also present the plan, but will give you the option to apply it
```
Please be patient as the AKS provisioning can take up to 30 minutes depending on the load on Azure systems. Afterwards there is a 5 minute delay before installing the *azure cli* on the new VM.

Have a look at the final output. It will contain something like **admin_vm_public_ip = "1.1.1.1"**. Use that ip and the username "vmadmin" to connect to the VM. Do not forget your private key too.

4. Prepare the ArgoCD environment
We need to first initialize the environment, and then configure it because the Kubernetes provider from Terraform does not wait for the Argo pods to get started before trying to configure them, but only created.
```
cd ../k8s-init/
terraform init
terraform apply -var="kubeconfig_file=../infra/aks_kubeconfig.yaml" # This is already defined in terraform.tfvars, but terraform refuses to use it, so we have to pass manually
```
Wait a minute or 2 to make sure that ArgoCD started, and then start configuring it.
```
cd ../k8s/
terraform init
terraform apply -var="kubeconfig_file=../infra/aks_kubeconfig.yaml" # Same reason as above
```
Now the output will give you the ip for the ArgoCD ui. Before we can log in we will need to retrieve the password for the admin account. On the KUBE-ADM vm run the following command:
```
kubectl -n argocd get secret argocd-initial-admin-secret  -o jsonpath="{.data.password}" | base64 -d; echo
```
Now you can login and see the applications.

This was created using a university account, and I had a limited number of IPs available. Because of that if you want to test that the actual app works you need to create a tunnel when connecting with ssh, and then inside the VM forward the app port (3000) to a port on the vm (8080 in this case).
On your PC (where you have access to a web browser):
```
ssh -i <path to private key> -L 8080:localhost:8080 vmadmin@<your vm ip>
```
And inside the VM:
```
kubectl port-forward -n test-app service/frontend-service 8080:3000
```
Now you can open a browser and the app will be available at "http://localhost:8080/".