#!/bin/bash
# setup.sh - Unified deployment and teardown script for Terraform and Kubernetes

set -e

# ========================
# 🎨 Output Styling
# ========================

USE_EMOJI=true # Set to false if terminal doesn't support emojis

if [ "$USE_EMOJI" = true ]; then
    CHECK="✅"
    WARN="⚠️"
    ERROR="🛑"
    INFO="ℹ️"
    SPARKLE="✨"
    ROCKET="🚀"
    TRASH="🗑️"
else
    CHECK="[OK]"
    WARN="[!]"
    ERROR="[ERROR]"
    INFO="[INFO]"
    SPARKLE="*"
    ROCKET="->"
    TRASH="[DEL]"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ========================
# 🔊 Output Helpers
# ========================

print_status() {
    echo ""
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_warning() {
    echo ""
    echo -e "${YELLOW}${WARN} $1${NC}"
}

print_error() {
    echo ""
    echo -e "${RED}${ERROR} $1${NC}"
}

# ========================
# ✅ Checks
# ========================

check_prerequisites() {
    print_status "Checking prerequisites..."

    for tool in terraform aws kubectl; do
        if ! command -v $tool >/dev/null 2>&1; then
            print_error "$tool is required but not installed. Aborting."
            exit 1
        fi
    done

    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured. Run 'aws configure'. Aborting."
        exit 1
    fi

    print_status "All prerequisites are installed!"
}

check_color_support() {
    if [ -t 1 ]; then
        return
    fi
    USE_EMOJI=false
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
}

ensure_k8s_deleted() {
    print_status "Ensuring Kubernetes resources are fully deleted before destroying Terraform..."

    cd "$BASE_DIR/terraform"
    NAMESPACE=$(terraform output -raw cors_proxy_namespace)

    for i in {1..30}; do
        PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
        DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
        SERVICES=$(kubectl get svc -n "$NAMESPACE" --no-headers 2>/dev/null | grep -v 'kubernetes' | wc -l)
        INGRESS=$(kubectl get ingress -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)

        if [[ "$PODS" -eq 0 && "$DEPLOYMENTS" -eq 0 && "$SERVICES" -eq 0 && "$INGRESS" -eq 0 ]]; then
            print_status "Kubernetes resources fully deleted."
            return
        fi

        echo "Waiting for K8s cleanup... Pods: $PODS, Deployments: $DEPLOYMENTS, Services: $SERVICES, Ingress: $INGRESS ($i/30)"
        sleep 10
    done

    print_error "Kubernetes resources were not fully deleted after 5 minutes. Aborting Terraform destroy."
    exit 1
}

# ========================
# ☁️ Terraform Infrastructure
# ========================

deploy_terraform() {
    print_status "Deploying infrastructure with Terraform..."

    cd "$BASE_DIR/terraform"

    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan

    print_status "Terraform infrastructure deployed successfully!"
}

destroy_terraform() {
    print_warning "Destroying infrastructure with Terraform..."

    cd "$BASE_DIR/terraform"
    terraform destroy -auto-approve

    print_status "Terraform infrastructure destroyed."
}

# ========================
# 🛠️ Kubernetes Deployment
# ========================

configure_kubectl() {
    print_status "Configuring kubectl..."

    cd "$BASE_DIR/terraform"

    if [ ! -f terraform.tfstate ]; then
        print_error "Terraform state not found. Deploy infrastructure first."
        exit 1
    fi

    CLUSTER_NAME=$(terraform output -raw cluster_name)
    AWS_REGION=$(terraform output -raw aws_region || echo "us-west-2")

    aws eks --region "$AWS_REGION" update-kubeconfig --name "$CLUSTER_NAME"

    print_status "kubectl configured successfully!"
}

deploy_k8() {
    print_status "Applying Kubernetes manifests..."

    K8_DIR="$BASE_DIR/kubernetes"

    kubectl apply -f "$K8_DIR/configMap.yaml"
    kubectl apply -f "$K8_DIR/service.yaml"
    kubectl apply -f "$K8_DIR/deployment.yaml"
    kubectl apply -f "$K8_DIR/podDisruption.yaml"
    kubectl apply -f "$K8_DIR/hpa.yaml"
    # kubectl apply -f "$K8_DIR/ingress.yaml"

    print_status "Kubernetes manifests applied."
}

destroy_k8() {
    print_warning "Deleting Kubernetes resources..."

    K8_DIR="$BASE_DIR/kubernetes"

    # kubectl delete -f "$K8_DIR/ingress.yaml" --ignore-not-found
    kubectl delete -f "$K8_DIR/hpa.yaml" --ignore-not-found
    kubectl delete -f "$K8_DIR/podDisruption.yaml" --ignore-not-found
    kubectl delete -f "$K8_DIR/deployment.yaml" --ignore-not-found
    kubectl delete -f "$K8_DIR/service.yaml" --ignore-not-found
    kubectl delete -f "$K8_DIR/configMap.yaml" --ignore-not-found
    kubectl delete -f "$K8_DIR/ingress.yaml" --ignore-not-found

    print_status "Kubernetes resources deleted."
}

# ========================
# 🧪 Wait & Status Helpers
# ========================

wait_for_services() {
    print_status "Waiting for services to be ready..."

    cd "$BASE_DIR/terraform"

    print_status "Getting Namespace..."
    NAMESPACE=$(terraform output -raw cors_proxy_namespace)

    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
    kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system
    kubectl wait --for=condition=available --timeout=300s deployment/cluster-autoscaler-aws-cluster-autoscaler -n kube-system
    kubectl wait --for=condition=available --timeout=300s deployment/cors-proxy -n "$NAMESPACE"

    for i in {1..60}; do
        # LB_HOSTNAME=$(kubectl get ingress cors-proxy-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        LB_HOSTNAME=$(kubectl get svc cors-proxy-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [[ -n "$LB_HOSTNAME" ]]; then
            print_status "LB provisioned: http://$LB_HOSTNAME"
            return
        fi
        echo "Waiting for LB... ($i/60)"
        sleep 10
    done

    # print_warning "LB hostname not available yet. You may check later with: kubectl get ingress cors-proxy-ingress -n "$NAMESPACE""
    print_warning "LB hostname not available yet. You may check later with: kubectl get svc cors-proxy-ingress -n "$NAMESPACE""
}

get_status() {
    print_status "Gathering current service status..."

    cd "$BASE_DIR/terraform"

    print_status "Getting Namespace..."
    NAMESPACE=$(terraform output -raw cors_proxy_namespace)

    echo "=== Cluster Info ==="
    kubectl cluster-info

    echo -e "\n=== Nodes ==="
    kubectl get nodes -o wide

    echo -e "\n=== CORS Proxy Deployment ==="
    kubectl get deployment cors-proxy -n "$NAMESPACE"

    echo -e "\n=== Pods ==="
    kubectl get pods -n "$NAMESPACE" -o wide

    echo -e "\n=== Services ==="
    kubectl get service -n "$NAMESPACE"

    # echo -e "\n=== Ingress ==="
    # kubectl get ingress -n "$NAMESPACE"

    # LB_HOSTNAME=$(kubectl get ingress cors-proxy-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
    LB_HOSTNAME=$(kubectl get svc cors-proxy-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
    echo -e "\nCORS Proxy URL: http://$LB_HOSTNAME"
}

# ========================
# 🔁 Main Flow
# ========================

main() {
    ACTION=${1:-"deploy"}
    TARGET=${2:-"all"}

    check_color_support

    case "$ACTION:$TARGET" in
    deploy:terraform)
        check_prerequisites
        ensure_k8s_deleted
        deploy_terraform
        ;;
    deploy:kubectl)
        check_prerequisites
        configure_kubectl
        deploy_k8
        wait_for_services
        get_status
        ;;
    deploy:all)
        check_prerequisites
        deploy_terraform
        configure_kubectl
        deploy_k8
        wait_for_services
        get_status
        print_status "${SPARKLE} All resources deployed successfully!"
        ;;
    destroy:terraform)
        configure_kubectl
        ensure_k8s_deleted
        destroy_terraform
        ;;
    destroy:kubectl)
        configure_kubectl
        destroy_k8
        ;;
    destroy:all)
        print_warning "This will destroy ALL resources. Proceed? (y/N)"
        read -r confirm
        if [[ "$confirm" =~ ^[yY](es)?$ ]]; then
            configure_kubectl
            destroy_k8
            ensure_k8s_deleted
            destroy_terraform
            print_status "${TRASH} All resources destroyed."
        else
            print_status "Destruction cancelled."
        fi
        ;;
    status:*)
        configure_kubectl
        get_status
        ;;
    *)
        echo -e "\n${INFO} Usage:"
        echo "./setup.sh deploy terraform      - Deploy only Terraform infrastructure"
        echo "./setup.sh deploy kubectl        - Deploy only Kubernetes resources"
        echo "./setup.sh deploy all            - Deploy both Terraform and Kubernetes"
        echo "./setup.sh destroy terraform     - Destroy only Terraform infrastructure"
        echo "./setup.sh destroy kubectl       - Destroy only Kubernetes resources"
        echo "./setup.sh destroy all           - Destroy both Terraform and Kubernetes"
        echo "./setup.sh status                - View current deployment status"
        exit 1
        ;;
    esac
}

main "$@"
