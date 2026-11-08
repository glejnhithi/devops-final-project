#ARGACD DIREKT

# resource "kubernetes_namespace_v1" "argocd" {
#   metadata {
#     name = "argocd-ns"
#   }
# }
#
# resource "helm_release" "argocd" {
#   name       = "argocd"
#   chart      = "argo-cd"
#   repository = "https://argoproj.github.io/argo-helm"
#   namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
#   version    = var.argocd_chart_vrs
#   wait       = true
#   timeout    = 600
# }

