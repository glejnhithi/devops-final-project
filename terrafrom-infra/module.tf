
# Module ARGOCD
module "argocd" {
  source = "./moduls/argocd"

  app_name = "argocd"
  ns_name  = "argocd-ns"

}
