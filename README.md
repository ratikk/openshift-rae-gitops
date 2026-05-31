# openshift-rae-gitops

GitOps configuration repository for the `rae` OpenShift cluster. Watched by Argo CD running in the cluster.

This repo is the **declarative cluster state**. Anything that lives on the cluster — operators, namespaces, CRs, Routes, ExternalSecrets — has its desired state defined here. Argo CD reconciles cluster reality to match.

## Companion repo

[`openshift-aws-replica`](https://github.com/ratikk/openshift-aws-replica) handles:
- AWS infrastructure (Terraform)
- OpenShift cluster bootstrap (install + GitOps operator)
- The `app-of-apps` Application that points Argo CD at THIS repo

## Architecture

```
openshift-aws-replica's install-cluster.yml runs to completion
  └── installs OpenShift GitOps operator
  └── applies app-of-apps.yaml (points Argo CD here)
        │
        ▼
Argo CD picks up apps/*.yaml from this repo
  ├── apps/metallb.yaml          → reconciles overlays/metallb/base/
  ├── apps/ingress.yaml          → reconciles overlays/ingress/base/
  ├── apps/external-secrets.yaml → reconciles overlays/external-secrets/base/
  ├── apps/keda.yaml             → reconciles overlays/keda/base/
  └── apps/vault.yaml            → reconciles overlays/vault/base/
        │
        ▼
Cluster becomes fully configured
```

## Layout

```
.
├── apps/                       Argo CD Application CRs (one per concern)
│   ├── metallb.yaml
│   ├── ingress.yaml
│   ├── external-secrets.yaml
│   ├── keda.yaml
│   └── vault.yaml
└── overlays/                   Kustomize bases (the actual manifests)
    ├── metallb/base/
    ├── ingress/base/
    ├── external-secrets/base/
    ├── keda/base/
    └── vault/base/
```

Each `apps/<concern>.yaml` is an Argo CD `Application` that points at the corresponding `overlays/<concern>/base/`. Kustomize renders the base; Argo CD applies the rendered manifests.

## Sync waves

Argo CD applies resources in **sync wave** order (annotation `argocd.argoproj.io/sync-wave`). Lower waves first. We use:

| Wave | Apps | Why |
|---:|---|---|
| -1 | metallb (Subscription, OperatorGroup) | Operator needs to be installed before its CRs are applied |
| 0  | metallb (CRs), keda, external-secrets, vault | Operators come up, CRs can be created |
| 1  | ingress | Needs MetalLB to allocate router VIP |
| 2  | (future workloads) | Applications using KEDA/ESO |

## How to add a new concern

1. Create `overlays/<concern>/base/` with `kustomization.yaml` + manifests
2. Add `apps/<concern>.yaml` Application CR pointing at the overlay
3. Commit + push to main
4. Argo CD picks it up within seconds (default 3-min poll, but webhooks faster)

## How to change a value

1. Edit the relevant file in `overlays/<concern>/base/`
2. Commit + push to main
3. Argo CD reconciles. Cluster matches git within ~3 min.

No `oc apply` commands run by humans. **Git is the only path to change cluster state.**
