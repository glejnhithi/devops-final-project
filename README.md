# DevOps Final Project — Terraform + Minikube + ArgoCD + GitLab

A local Kubernetes GitOps lab: Terraform installs ArgoCD; ArgoCD continuously deploys a frontend, FastAPI backend and PostgreSQL using Helm. GitLab CI builds and publishes application images.

## Architecture

```text
GitLab source repositories -> GitLab CI -> GitLab Container Registry
                                                    |
Terraform -> Minikube -> ArgoCD <--- GitLab gitops repo
                          |                         |
                          +---- Helm applications <-+
                                  frontend -> backend -> PostgreSQL (PVC)
```

**Ownership boundary:** Terraform owns the `argocd` namespace and ArgoCD Helm release. ArgoCD owns the `dev` namespace and all application resources. Do not manage the same resource with both tools.

## 1. Prerequisites

- Docker Engine/Desktop running
- Minikube, kubectl, Terraform >= 1.10, Helm 3, Git
- At least ~8 GiB RAM available to Minikube (12 GiB+ recommended for optional monitoring)
- A GitLab Group and GitLab Container Registry
- GitLab Runner for build jobs (shared runners are fine; they do not need access to Minikube)

Check:

```bash
docker info
minikube version
kubectl version --client
terraform version
helm version
```

## 2. GitLab repositories

This ZIP contains **four ready-to-split folders**:

| Local folder | Suggested GitLab repository |
| --- | --- |
| `terraform-infrastructure/` | `terraform-infrastructure` |
| `gitops/` | `gitops` |
| `frontend/` | `frontend` |
| `backend/` | `backend` |

Helm charts live in `gitops/charts/` to keep the first implementation simple. You can extract them into a separate `helm-charts` repository later. The README and architecture notes can likewise move into a `documentation` repo.

Create these four GitLab repositories, push the corresponding folder contents, then replace the placeholders below. **Do not push `.tfstate`, secrets or `.env` files.**

## 3. Start Minikube

```bash
minikube start --driver=docker --cpus=4 --memory=8192
kubectl config use-context minikube
kubectl get nodes
kubectl get storageclass
```

If the Docker driver or available resources differ, adapt the flags.

## 4. Bootstrap ArgoCD with Terraform

```bash
cd terraform-infrastructure
cp terraform.tfvars.example terraform.tfvars
# Choose an existing compatible ArgoCD Helm chart version from the upstream repository.
# Set argocd_chart_version in terraform.tfvars.
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
kubectl get pods -n argocd
```

Terraform state stays **local** in this demo. Never commit it. CI can run formatting/validation, but Terraform apply must run on a machine with access to Minikube.

Open the ArgoCD UI:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Visit `https://localhost:8080` (the local certificate is self-signed). Obtain the initial password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode; echo
```

## 5. Configure GitOps

1. Push `gitops/` to the GitLab `gitops` repository.
2. Replace `REPLACE_WITH_GITOPS_REPO_URL` in **all** files under `gitops/` with the **same** GitLab HTTPS repository URL ending in `.git`.
3. For a private GitLab repository, create a **read-only** Deploy Token with `read_repository` and register it with ArgoCD (UI: Settings > Repositories). Do not commit the token. For a public repository, this step is unnecessary.
4. In `gitops/charts/frontend/values.yaml` and `gitops/charts/backend/values.yaml`, replace image repositories with the GitLab Container Registry paths produced by CI.
5. Configure image pull credentials for private container images (see section 7).
6. Commit and push the GitOps changes.
7. Bootstrap the root application once:

```bash
kubectl apply -n argocd -f gitops/bootstrap/root-app.yaml
kubectl get applications -n argocd
```

The root application reads `gitops/applications/`, which defines the three child applications. Those children deploy Helm charts from `gitops/charts/`. ArgoCD then reconciles changes automatically.

## 6. Build and publish images

Both `frontend/` and `backend/` contain a `.gitlab-ci.yml` using Docker-in-Docker. The GitLab Runner must allow privileged Docker-in-Docker jobs, or you must replace the build strategy with a supported rootless builder.

Push each source repo to GitLab and confirm the pipeline publishes:

```text
$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

Use the actual published image paths and tags in the GitOps chart values. For the first run, update tags manually in Git. Later, automate this with a bot or a GitLab pipeline that opens an MR to the GitOps repository.

## 7. Private GitLab Container Registry

For private images, create a GitLab Deploy Token with `read_registry`, then create an image pull secret in namespace `dev`:

```bash
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl -n dev create secret docker-registry gitlab-registry \
  --docker-server=registry.gitlab.com \
  --docker-username='<DEPLOY_TOKEN_USERNAME>' \
  --docker-password='<DEPLOY_TOKEN_VALUE>'
```

Set `imagePullSecrets: [{name: gitlab-registry}]` in frontend/backend Helm values. If using self-managed GitLab, replace the registry hostname. The secret is deliberately created outside Git; for a production-like implementation, use Sealed Secrets or External Secrets and establish clear ownership.

The PostgreSQL password is also created locally and is **not** committed:

```bash
kubectl -n dev create secret generic postgres-auth \
  --from-literal=password='<CHOOSE_A_STRONG_LOCAL_PASSWORD>'
```

These secrets must exist before the corresponding pods start. If you recreate Minikube, recreate them.

## 8. Access the application

Wait for ArgoCD sync and pods:

```bash
kubectl get applications -n argocd
kubectl get pods,svc,pvc -n dev
```

In separate terminals:

```bash
kubectl -n dev port-forward svc/frontend 8081:80
kubectl -n dev port-forward svc/backend 8082:8000
```

- Frontend: http://localhost:8081
- Backend health: http://localhost:8082/health
- Backend DB check: http://localhost:8082/db-health

The frontend includes a link to the backend health URL on port 8082. This is a minimal demo; ingress and same-origin API routing are phase-two improvements.

## 9. Test GitOps self-healing

1. In `gitops/charts/frontend/values.yaml`, change `replicaCount: 1` to `replicaCount: 2`.
2. Commit and push.
3. Watch ArgoCD reconcile:

```bash
kubectl -n dev get deploy frontend -w
```

4. Restore `replicaCount: 1` in Git and push.

Do not use `terraform apply` for application changes.

## 10. Monitoring and enhancements

Add these **after** the base stack works:

- `ingress-nginx` and local hostnames
- `kube-prometheus-stack` (Prometheus/Grafana)
- Resource quotas, network policies and backup/restore
- Helm lint and integration tests
- GitLab MR workflow for automated image-tag updates
- Secret management (Sealed Secrets/External Secrets)

## 11. Troubleshooting

```bash
kubectl get nodes
kubectl -n argocd get pods
kubectl -n argocd get applications
kubectl -n dev get pods,svc,pvc,secrets
kubectl -n dev describe pod <POD_NAME>
kubectl -n dev logs deployment/backend
kubectl -n dev logs deployment/postgres
```

- `ImagePullBackOff`: image/tag incorrect or missing `gitlab-registry` pull secret.
- `CreateContainerConfigError`: missing `postgres-auth` secret.
- `Pending` PostgreSQL: check Minikube StorageClass/PVC.
- ArgoCD `ComparisonError`: check repository credentials and placeholder URL.
- CI DinD failure: runner may not support privileged mode.
- `terraform apply` fails in CI: shared runner cannot access local Minikube.

## 12. Cleanup

```bash
cd terraform-infrastructure
terraform destroy
cd ..
minikube delete
```

Remove ArgoCD-managed applications before Terraform destroy if you want a clean Kubernetes teardown. Deleting Minikube destroys the local cluster and its storage.

## Acceptance criteria

- [ ] Minikube cluster running
- [ ] Terraform plan/apply succeeds
- [ ] ArgoCD running
- [ ] Root + three child ArgoCD applications Healthy/Synced
- [ ] Frontend and backend respond
- [ ] Backend can query PostgreSQL
- [ ] PostgreSQL PVC Bound
- [ ] GitLab pipelines build/push images
- [ ] Git commit triggers ArgoCD sync
- [ ] Architecture and screenshots documented
