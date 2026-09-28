<br/>

<p align="center">
  <img src="https://skillicons.dev/icons?i=kubernetes,azure,terraform,prometheus,grafana,bash&perline=6" alt="Kubernetes, Azure, Terraform, Prometheus, Grafana, Bash" />
</p>

<h1 align="center">Cluster Monitoring with Operators on AKS</h1>

<p align="center">
  <i>Prometheus, Alertmanager and Grafana deployed by the Prometheus operator, TLS certificates issued by cert-manager, Grafana exposed through an HTTPS reverse proxy</i>
</p>

<p align="center"><sub>Contributors</sub></p>

<p align="center">
  <a href="https://github.com/WhiteMuush"><img src="https://github.com/WhiteMuush.png" width="56" alt="WhiteMuush" /></a>
  <a href="https://github.com/jaims-31"><img src="https://github.com/jaims-31.png" width="56" alt="jaims-31" /></a>
</p>

<br/>

---

<br/>

## Project layout

```
.
├── Makefile                  Entry point, `make` opens the interactive menu
├── makefiles/                One fragment per menu section: infrastructure, deploy, access, checks
├── scripts/                  The logic behind each target
│   ├── lib.sh                Shared helpers: Ansible style output, log file
│   ├── menu.sh               Interactive menu built from the make targets
│   ├── kube.sh               Shared Kubernetes helpers: context, reachability
│   ├── helm.sh               Shared Helm helpers: release definition, config checksum
│   ├── terraform.sh          init, fmt, validate, plan, confirmed apply
│   ├── helm-release.sh       Idempotent install or upgrade of one Helm release
│   ├── k8s-apply.sh          Applies k8s/<component>/, waits for Ready resources
│   ├── status.sh             Read-only health report behind `make status`
│   ├── grafana.sh            Opens Grafana, admin password copied to the clipboard
│   ├── open-ui.sh            Port-forwards to Prometheus, Alertmanager, Traefik, never exposed
│   └── browser.sh            Shared helper: opens a URL in the browser
├── terraform/                Azure side
│   ├── imports.tf            Brings the existing AKS cluster under Terraform
│   ├── main.tf               Cluster, monitoring node pool, static public IP
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── helm/                     One folder per Helm release
│   ├── cert-manager/         release.env (chart, version, namespace) + values.yaml
│   ├── kube-prometheus-stack/
│   └── traefik/              HTTPS reverse proxy
├── k8s/                      Custom manifests applied once the operators run
│   ├── namespaces/           Namespaces needed before the Helm releases
│   ├── cert-manager/         Self-signed ClusterIssuer, Grafana certificate
│   ├── monitoring/           Alert rules for pods and certificates (PrometheusRule)
│   ├── grafana/              Dashboards as JSON, loaded by kustomize as ConfigMaps
│   └── ingress/              Grafana Ingress served by Traefik
└── docs/
    └── CONSIGNES.md          The brief
```

Logs of every run are appended to `.logs/`, one file per script.

<br/>

---

<br/>

## Documentation

**Azure and Terraform**

- [Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/aks/)
- [Static public IP for the AKS load balancer](https://learn.microsoft.com/en-us/azure/aks/static-ip)
- [Terraform `import` block](https://developer.hashicorp.com/terraform/language/import)
- [`azurerm_kubernetes_cluster`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
- [`azurerm_kubernetes_cluster_node_pool`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool)
- [`azurerm_public_ip`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip)

**Helm**

- [`helm upgrade`](https://helm.sh/docs/helm/helm_upgrade/)

**cert-manager**

- [Install with Helm](https://cert-manager.io/docs/installation/helm/)
- [SelfSigned issuer](https://cert-manager.io/docs/configuration/selfsigned/)
- [Certificate resource](https://cert-manager.io/docs/usage/certificate/)

**Reverse proxy**

- [Traefik](https://doc.traefik.io/traefik/)
- [Traefik Kubernetes Ingress provider](https://doc.traefik.io/traefik/providers/kubernetes-ingress/)
- [Traefik Helm chart](https://github.com/traefik/traefik-helm-chart)
- Traefik replaces [ingress-nginx](https://github.com/kubernetes/ingress-nginx), whose repository is archived

**Monitoring**

- [Prometheus operator](https://prometheus-operator.dev/)
- [kube-prometheus-stack chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana](https://grafana.com/docs/grafana/latest/)

<br/>

---

<br/>

<p align="center"><sub>Brief in <a href="docs/CONSIGNES.md">docs/CONSIGNES.md</a></sub></p>
