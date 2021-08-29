# Introduction

This section documents the overall infrastructure for Netsoc. Our new infrastructure is Kubernetes-focused, with the
majority of our services being deployed this way.

- `napalm`, `spoon` and `cube` run [k3s](https://k3s.io) on bare metal
- `gandalf` is a VM host for any workloads that are impractical to deploy in Kubernetes
- `saruman` is a k3s node inside a VM on `gandalf`
- `mail` is a [mailcow](https://mailcow.email/)-based mail server for internal email (automated notifications, support,
  etc.)

For details on all of our Kubernetes deployments, see the [GitOps documentation](../gitops/). All of the deployments
are [defined in Git]({{ github_org }}/gitops) using [GitOps princicples](https://www.gitops.tech/).
