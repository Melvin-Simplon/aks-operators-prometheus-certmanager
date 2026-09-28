# Brief

## Summary

In this brief, you will set up a Kubernetes cluster with a Prometheus/Grafana observability stack using an operator, then Cert-Manager, also with an operator, and an HTTPS proxy to expose Grafana outside the cluster.

## Instructions

- Find a domain name specific to your group (unique if possible)
- Install the cert-manager operator
- Provision a self-signed certificate for your domain
- Install the Prometheus operator
- Deploy your main Prometheus instance
- Deploy an Alertmanager instance
- Deploy the node_exporters
- Send node metrics to the main Prometheus (NO STATIC CONFIG!! use the operator)
- Deploy Grafana and configure it properly (persistence, data source)
- Deploy an HTTPS reverse proxy (use the certificate generated earlier) exposed outside the cluster with an L4 Load Balancer
- Create a dashboard for the nodes
- Create a dashboard for the certificate(s)
- Set up alerts for pods and certificates

## Bonus

### Easy

- Cluster permissions are properly managed with Entra ID
- Data persistence is properly handled with Azure disks for the whole stack (backups, storage type, size...)

### Medium

- The Load Balancer resource can be deleted and recreated without losing the public IP of the Azure LB (static IP)

### Hard

- You use a root certificate to generate your certificates
- You use an intermediate certificate to generate your certificates

### Excuse me?

- You have set up a PKI in a HashiCorp Vault deployed in your cluster
