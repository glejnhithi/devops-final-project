output "argocd_ns" {
  value = kubernetes_namespace_v1.argocd.metadata[0].name
}