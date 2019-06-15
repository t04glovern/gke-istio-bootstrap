# GKE Private - Boostrap

Google Cloud Platform Deployment Manager bootstrap for GKE

---

## Architecture

---

![Architecture Diagram](img/architecture.png)

---

## Setup

---

### Deploy Script Usage

```bash
./deploy.sh <project_id> <resource> <action>
```

Resources must be deployed and removed in the following order

| create             | delete              |
|--------------------|---------------------|
| iam                | dns                 |
| network            | bastion             |
| cloud-router       | gke                 |
| gke                | cloud-router        |
| bastion            | network             |
| dns                | iam

Or simply run the following to bring it all up

```bash
./deploy.sh <project_id> all create
```

---

## Manage

---

### Connect

Connect to the bastion host and manage the kubernetes cluster from there using the steps below

#### SCP Bastion

```bash
gcloud compute scp \
  --recurse ./k8s* <project_id>-bastion:~/ \
  --zone australia-southeast1-a
```

#### SSH Bastion

```bash
gcloud compute ssh <project_id>-bastion \
  --project <project_id> \
  --zone australia-southeast1-a
```

#### Kubernetes Connect

```bash
gcloud container clusters get-credentials <project_id>-gke \
  --project <project_id> \
  --region australia-southeast1
```

---

## Istio

---

### Istio Install

```bash
# Initialize Istio
./k8s/istio/istio.sh <project_id> init

# Install Istio Services
./k8s/istio/istio.sh <project_id> install
```

### Configure Istio

```bash
kubectl apply -f k8s/istio/networking
```

---

## Helm

---

### Role-based Access Control (RBAC)

We'll deploy an RBAC configuration that is used by helm. Perform the following actions from the Bastion server

```bash
# Create tiller service account & cluster role binding
cd k8s
kubectl create -f rbac-config.yaml

# init helm with the service account
helm init --service-account tiller --history-max 200
```

### Install External DNS

```bash
helm install \
  --name external-dns stable/external-dns \
  -f external-dns.yaml --wait
```

### Install Prometheus & Grafana

```bash
helm install \
  --name prometheus stable/prometheus \
  -f prometheus/values.yaml --wait

kubectl apply \
  -f grafana/configmap.yaml
helm install \
  --name grafana stable/grafana \
  -f grafana/values.yaml --wait
```

### Delete Packages

```bash
helm delete --purge external-dns grafana prometheus
kubectl delete -f k8s/istio/networking
./k8s/istio/istio.sh <project_id> remove
```

---

## Attribution

---

- RBAC Configuration Example - [https://github.com/helm/helm/blob/master/docs/rbac.md](https://github.com/helm/helm/blob/master/docs/rbac.md)
- Deployment Manager samples - [https://github.com/GoogleCloudPlatform/deploymentmanager-samples](https://github.com/GoogleCloudPlatform/deploymentmanager-samples)
  - [cloud_router](https://github.com/GoogleCloudPlatform/deploymentmanager-samples/tree/master/community/cloud-foundation/templates/cloud_router)
  - [firewall](https://github.com/GoogleCloudPlatform/deploymentmanager-samples/tree/master/community/cloud-foundation/templates/firewall)
  - [gke](https://github.com/GoogleCloudPlatform/deploymentmanager-samples/tree/master/community/cloud-foundation/templates/gke) - with modifications from [Praveen Chamarthi](https://github.com/GoogleCloudPlatform/deploymentmanager-samples/pull/326)
  - [iam_member](https://github.com/GoogleCloudPlatform/deploymentmanager-samples/tree/master/community/cloud-foundation/templates/iam_member)
  - [network](https://github.com/GoogleCloudPlatform/deploymentmanager-samples/tree/master/community/cloud-foundation/templates/network)
