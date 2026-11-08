provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
  config_context = "minikube"
}

provider "helm" {
  kubernetes = {
    config_path = pathexpand("~/.kube/config")
    config_context = "minikube"
  }
}