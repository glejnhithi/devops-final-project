variable "argocd_chart_vrs" {
  type = string
  default = "7.7.1"
  description = "Pin an available argo-cd Helm chart version"
}

variable "app_name" {
  type = string
}

variable "ns_name" {
  type = string
}