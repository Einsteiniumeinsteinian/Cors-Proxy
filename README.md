# CORS Proxy - Production-Ready Kubernetes Deployment

A highly available, auto-scaling CORS proxy service deployed on AWS EKS, capable of handling 1000+ requests per second with comprehensive monitoring and testing.

## 🏗️ Architecture Overview

This solution provides a production-ready CORS proxy service with the following components:

- **AWS EKS Cluster**: Managed Kubernetes with high availability
- **Auto Scaling**: Horizontal Pod Autoscaler (HPA) and Cluster Autoscaler
- **Load Balancing**: Network/Application Load Balancer for traffic distribution
- **Load Testing**: k6 testing suite

```diagram
┌───────────────────────────────────────────────────────────────────────────────┐
│                                  AWS VPC                                     │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                            Public Subnet (AZ1)                          │ │
│  │                                                                         │ │
│  │                        ┌──────────────────┐                             │ │
│  │                        │ Public NLB       │                             │ │
│  │                        │ (TCP/80)        │◄────────────────────────────┼─┼─────┐
│  │                        └────────┬─────────┘                             │ │     │
│  │                                 │                                       │ │     │
│  │                                 ▼                                       │ │     │
│  │  ┌───────────────────────────────────────────────────────────────────┐ │ │     │
│  │  │                        Private Subnets                            │ │ │     │
│  │  │                                                                   │ │ │     │
│  │  │  ┌──────────────────┐                     ┌──────────────────┐    │ │ │     │
│  │  │  │ Private Subnet   │                     │ Private Subnet   │    │ │ │     │
│  │  │  │ (AZ1: 10.0.1.0/24)│                     │ (AZ2: 10.0.2.0/24)│    │ │ │     │
│  │  │  │                  │                     │                  │    │ │ │     │
│  │  │  │ ┌──────────────┐ │                     │ ┌──────────────┐ │    │ │ │     │
│  │  │  │ │ EKS Node     │ │                     │ │ EKS Node     │ │    │ │ │     │
│  │  │  │ │ ┌──────────┐ │ │                     │ │ ┌──────────┐ │ │    │ │ │     │
│  │  │  │ │ │CORS-Proxy│ │ │                     │ │ │CORS-Proxy│ │ │    │ │ │     │
│  │  │  │ │ │ Pod      │◄─┼─────────────────────┼─┼─┤ Pod      │ │ │    │ │ │     │
│  │  │  │ │ └──────────┘ │ │                     │ │ └──────────┘ │ │    │ │ │     │
│  │  │  │ │ (cors-proxy  │ │                     │ │ (cors-proxy  │ │    │ │ │     │
│  │  │  │ │  namespace)  │ │                     │ │  namespace)  │ │    │ │ │     │
│  │  │  │ │              │ │                     │ │              │ │    │ │ │     │
│  │  │  │ │ ┌──────────┐ │ │                     │ │ ┌──────────┐ │ │    │ │ │     │
│  │  │  │ │ │Metric    │ │ │                     │ │ │Metric    │ │ │    │ │ │     │
│  │  │  │ │ │Server    │ │ │                     │ │ │Server    │ │ │    │ │ │     │
│  │  │  │ │ └──────────┘ │ │                     │ │ └──────────┘ │ │    │ │ │     │
│  │  │  │ │ (kube-system │ │                     │ │ (kube-system │ │    │ │ │     │
│  │  │  │ │  namespace)  │ │                     │ │  namespace)  │ │    │ │ │     │
│  │  │  │ │              │ │                     │ │              │ │    │ │ │     │
│  │  │  │ │ ┌──────────┐ │ │                     │ │ ┌──────────┐ │ │    │ │ │     │
│  │  │  │ │ │Cluster   │ │ │                     │ │ │Cluster   │ │ │    │ │ │     │
│  │  │  │ │ │Autoscaler│ │ │                     │ │ │Autoscaler│ │ │    │ │ │     │
│  │  │  │ │ └──────────┘ │ │                     │ │ └──────────┘ │ │    │ │ │     │
│  │  │  │ │ (kube-system │ │                     │ │ (kube-system │ │    │ │ │     │
│  │  │  │ │  namespace)  │ │                     │ │  namespace)  │ │    │ │ │     │
│  │  │  │ └──────────────┘ │                     │ └──────────────┘ │    │ │ │     │
│  │  │  └──────────────────┘                     └──────────────────┘    │ │ │     │
│  │  └───────────────────────────────────────────────────────────────────┘ │ │     │
│  └─────────────────────────────────────────────────────────────────────────┘ │     │
└───────────────────────────────────────────────────────────────────────────────┘     │
                                                                                     │
                                                                                     ▼
                                                                           ┌───────────────────┐
                                                                           │    k6 Load Tester  │
                                                                           │   (Inside VPC/    │
                                                                           │   Same Network)   │
                                                                           └───────────────────┘
```

## 🚀 Quick Start

### Prerequisites

Ensure you have the following tools installed:

- [AWS CLI](https://aws.amazon.com/cli/) (configured with appropriate permissions)
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [k6](https://k6.io/docs/getting-started/installation/) (for load testing)

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/cors-proxy-kubernetes.git
cd cors-proxy-kubernetes
```

### 2. Configure AWS Credentials

```bash
aws configure
# or
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-west-2"
```

### 3. Deploy Infrastructure

```bash
# Make the script executable
chmod +x scripts/setup.sh

# Deploy everything (Terraform + Kubernetes) - Recommended for first-time setup
./scripts/setup.sh deploy all

# Alternative: Deploy components separately
# Deploy only Terraform infrastructure
./scripts/setup.sh deploy terraform

# Deploy only Kubernetes resources (after Terraform is deployed)
./scripts/setup.sh deploy kubectl
```

### 4. Deploy Manually

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan -out=tfplan


# Deploy infrastructure (takes ~15-20 minutes)
terraform apply tfplan

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name cors-proxy-cluster

# Deploy Kubernetes components
cd ../kubernetes
kubectl apply -f configMap.yaml
kubectl apply -f service.yaml # Recommended for High Traffic
kubectl apply -f deployment.yaml
kubectl apply -f podDisruption.yaml
kubectl apply -f hpa.yaml
kubectl apply -f ingress.yaml #Use if you want to use an ALB. alternative to service.yaml

# Verify deployment
kubectl get all -n cors-proxy
```

### 6. Run Load Tests

```bash
# Make the test script executable (run once)
chmod +x scripts/test.sh

# Run all steps: deploy infrastructure, deploy Kubernetes, then run the load test
# Recommended for first-time setup or full test cycle
./scripts/test.sh all

# Alternative: Run smoke tests (basic Terraform-only deployment to validate infra)
./scripts/test.sh smoke

# Run load tests only (requires that the infrastructure and Kubernetes resources are already deployed)
./scripts/test.sh load
```

## Cleanup

Run the script to clean up

```bash
# Make the script executable
chmod +x scripts/setup.sh

# Deploy everything (Terraform + Kubernetes) - Recommended for first-time setup
./scripts/setup.sh destroy all

# Alternative: Deploy components separately
# Deploy only Terraform infrastructure
./scripts/setup.sh destroy terraform

# Deploy only Kubernetes resources (after Terraform is deployed)
./scripts/setup.sh destroy kubectl
```

## 📁 Project Structure

```tree
cors-proxy-kubernetes/
├── README.md                                  # Project overview and usage guide

├── Documents/                                 # Documentation and assets
│   ├── Architecture.png                       # OLD architecture diagram (deprecated)
│   ├── Architecture.txt                       # Notes or ASCII version of architecture
│   ├── DevOps Coding Challenge.pdf            # Challenge instructions or assignment

├── terraform/                                 # Infrastructure as Code (IaC)
│   ├── providers.tf                           # AWS provider and backend configs
│   ├── variables.tf                           # All variable declarations
│   ├── outputs.tf                             # Output values like endpoint URLs
│   ├── eks.tf                                 # EKS cluster and node group resources
│   ├── vpc.tf                                 # VPC, subnets, route tables, etc.
│   ├── data.tf                                # Data sources (e.g., AMI, IAM roles)
│   ├── k8.tf                                  # Helm releases: metrics-server, autoscaler, ALB controller
│   ├── jsons/
│   │   └── aws-load-balancer-policy.json      # Custom AWS LB listener policy config

├── kubernetes/                                # Kubernetes YAML manifests
│   ├── configMap.yaml                         # Proxy configuration via environment variables
│   ├── deployment.yaml                        # CORS proxy Deployment
│   ├── service.yaml                           # ClusterIP or LoadBalancer service
│   ├── ingress.yaml                           # Ingress config for external access
│   ├── hpa.yaml                               # HorizontalPodAutoscaler for autoscaling
│   ├── podDisruption.yaml                     # PodDisruptionBudget for high availability

├── k6/                                        # Load testing scripts using k6
│   ├── load-test.js                           # Load test ramping up to 2500 VUs
│   ├── smoke-test.js                          # Light, fast test to validate health

├── scripts/                                   # Utility shell scripts
│   ├── setup.sh                               # Deploys Terraform infra and K8s resources
│   ├── test.sh                                # Runs k6 tests locally or in cluster

└── docs/                                      # Extra documentation (optional if needed)
    ├── ARCHITECTURE.md                        # Explanation with image reference
```

## 📊 Performance Targets

The system is designed to meet the following performance criteria:

| Metric | Target | Description |
|--------|--------|-------------|
| **Baseline RPS** | 1,000 | Sustained requests per second |
| **Burst Capacity** | 5,000 | Peak requests per second |
| **Error Rate** | < 1% | Maximum acceptable error rate |
| **Availability** | 99.9% | Uptime SLA target |

## ⚡ Auto Scaling Configuration

### Horizontal Pod Autoscaler (HPA)

- **CPU Target**: 70% utilization
- **Memory Target**: 80% utilization
- **Min Replicas**: 4
- **Max Replicas**: 20
- **Scale-up**: Add pods when CPU > 70% for 1min
- **Scale-down**: Remove pods when CPU < 50% for 5m

### Cluster Autoscaler

- **Node Types**: m5.large to m5.4xlarge
- **Min Nodes**: 4
- **Max Nodes**: 8
- **Scale-up Trigger**: Unschedulable pods
- **Scale-down**: Nodes with < 50% utilization for 10m

## 🔧 Configuration

### Resource Limits

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "200m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

### Success Criteria

✅ **Pass Criteria:**

- Handle 1,000 RPS with
- Successful auto-scaling events

## 💰 Cost Optimization

### Estimated Monthly Costs (US-West-2)

| Component | Cost Range | Notes |
|-----------|------------|-------|
| EKS Control Plane | $72 | Fixed cost |
| Worker Nodes (3-10 m5.large) | $150-500 | Based on usage |
| Application Load Balancer | $20 | Plus data processing |
| Network Load Balancer | $17 | Plus data processing |
| **Total** | **$240-622** | Scales with load |

### Cost Optimization Strategies

1. **Spot Instances**: Used for non-critical workloads (50-90% savings)
2. **Right-sizing**: Monitor and adjust instance sizes using load test

### To Scale Beyond 1000 RPS

To achieve 10k–100k RPS:

- Use a high-performance CORS proxy implementation (e.g., NGINX, Envoy).
- Enable connection pooling, keep-alive headers, and response caching.
- Add a caching layer like Redis or Varnish for repetitive API requests.
- Scale Kubernetes nodes with optimized instance types (e.g., `c6g.large`).
- Use CloudFront for global distribution
- Use a service mesh (e.g., Istio) to manage traffic and observability.
- Deploy across multiple AWS regions and use Route53 for distribution.

## Limitations

- No support regional failover by default.
- Larger Instance Sizes.
- Cold starts during pod scaling can affect initial request latency.
- Load Balancer throughput might limit performance at higher request rates.
- AWS Account limits.
- proper spike management using PDB and drains.
- script can be more modular to account for various variables like cluster and region name.

## 🔭 Future Improvements

The current setup focuses on delivering a minimal, functional deployment of a CORS proxy on EKS. Below are planned enhancements across security, reliability, observability, performance, and operational best practices to improve robustness and production readiness.

## 🔒 Security Features

### Infrastructure Security

- ✅ Private subnets for worker nodes
- ✅ Security groups with minimal required ports
- ✅ Network ACLs for additional protection
- ✅ Encryption at rest and in transit

### Application Security

- ✅ Pod security contexts (non-root user)
- ✅ Network policies for traffic isolation
- ✅ Resource quotas and limits
- ✅ Secrets management via AWS Secrets Manager

### Access Control

- ✅ RBAC policies for Kubernetes
- ✅ Improved handling of user, and access control policies for IAM users.
- ✅ IAM roles for service accounts with limited scopes
- ✅ Audit logging enabled
- ✅ Least privilege access principles
- ✅ Apply **PodSecurityPolicies** (or their successors like OPA Gatekeeper or Kyverno)
- ✅ Enable **encryption at rest** for secrets in etcd

### 📊 Observability

- ✅ Integrate with **Prometheus and Grafana** for metrics and dashboards
- ✅ Enable **Kubernetes event logging and alerting**
- ✅ Forward logs using **FluentBit or Fluentd to a centralized store** (e.g., CloudWatch, Loki)

### 📦 Terraform Improvements

To ensure infrastructure is scalable, reusable, and easier to manage, the following improvements are planned for the Terraform codebase:

- ✅ **Remote backend** with state locking (e.g., using S3 + DynamoDB)
- ✅ **Workspaces** for environment separation (dev, staging, prod)
- ✅ **Module abstraction** for VPCs and Node Groups
- ✅ **Terraform Cloud or CI Integration** for automated plan/apply
- ✅ **State file encryption** for securing sensitive output
- ✅ **Lifecycle rules** for safe resource recreation and prevention of accidental deletions
- ✅ **Dynamic blocks** for cleaner repeated resource definitions
- ✅ **Tagging strategy** for cost allocation, environment tracking, and governance
- ✅ **Compliance checks** using, `tflint`, and `tfsec`
- ✅ **Version pinning** of providers and modules for repeatable builds
- ✅ **Use of Tfvars** to assist with diff environment management

### 🚀 Performance

- ✅ Add request rate limiting to prevent abuse
- ✅ Set optimized resource requests and limits per container
- ✅ Implement horizontal pod autoscaling based on RPS
- ✅ Use cross-zone load balancing to distribute traffic efficiently

---
