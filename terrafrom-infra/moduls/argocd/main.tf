resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.ns_name
  }
}

resource "helm_release" "argocd" {
  name       = var.app_name
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  version    = var.argocd_chart_vrs
  wait       = true
  timeout    = 600
/*  values = [
    yamldecode({
      server = {
        type = "NodePort"
      }
      extraArgs = [
        "--insecure"
      ]
    })
  ]*/
}