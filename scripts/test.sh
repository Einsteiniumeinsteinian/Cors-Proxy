#!/bin/bash
# test.sh - Load testing script using k6

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if k6 is installed
check_k6() {
    if ! command -v k6 &> /dev/null; then
        print_error "k6 is not installed. Installing k6..."
        
        # Install k6 based on OS
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo gpg -k
            sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
            echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
            sudo apt-get update
            sudo apt-get install k6
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &> /dev/null; then
                brew install k6
            else
                print_error "Please install Homebrew first or install k6 manually"
                exit 1
            fi
        else
            print_error "Please install k6 manually from https://k6.io/docs/getting-started/installation/"
            exit 1
        fi
    fi
}

# Get the load balancer URL
get_load_balancer_url() {
    print_status "Getting load balancer URL..."
    
    # LB_HOSTNAME=$(kubectl get ingress cors-proxy-ingress -n cors-proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
      LB_HOSTNAME=$(kubectl get svc cors-proxy-service -n cors-proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    
    if [[ -z "$LB_HOSTNAME" ]]; then
        print_error "Load balancer hostname not found. Make sure the cors-proxy-service is properly configured."
        print_status "Checking service status..."
        kubectl describe svc cors-proxy-service -n cors-proxy
        exit 1
    fi
    
    BASE_URL="http://$LB_HOSTNAME"
    print_status "Load balancer URL: $BASE_URL"
    
    # Test if the URL is accessible
    print_status "Testing connectivity to load balancer..."
    for i in {1..30}; do
        if curl -s --max-time 10 "$BASE_URL/health" > /dev/null; then
            print_status "Load balancer is accessible!"
            break
        fi
        echo "Waiting for load balancer to be ready... ($i/30)"
        sleep 10
    done
    
    if ! curl -s --max-time 10 "$BASE_URL/health" > /dev/null; then
        print_error "Load balancer is not accessible. Please check the deployment."
        exit 1
    fi
}

# Run smoke test
run_smoke_test() {
    print_status "Running smoke test..."
    
    k6 run --env BASE_URL="$BASE_URL" "$BASE_DIR/k6/smoke-test.js"
    
    if [[ $? -eq 0 ]]; then
        print_status "✅ Smoke test passed!"
    else
        print_error "❌ Smoke test failed!"
        return 1
    fi
}

# Run load test
run_load_test() {
    print_status "Running full load test..."
    print_warning "This test will ramp up to 5000 concurrent users and run for about 30 minutes."
    print_warning "Make sure your cluster has enough capacity!"
    
    # Create results directory
    mkdir -p test-results
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    RESULTS_FILE="test-results/load-test-results-$TIMESTAMP.json"
    
    echo base
    # Run the load test
    k6 run --env BASE_URL="$BASE_URL" --out json="$RESULTS_FILE" "$BASE_DIR/k6/load-test.js"
    
    if [[ $? -eq 0 ]]; then
        print_status "✅ Load test completed successfully!"
        print_status "Results saved to: $RESULTS_FILE"
    else
        print_error "❌ Load test failed!"
        return 1
    fi
}

# Monitor cluster during test
monitor_cluster() {
    print_status "Monitoring cluster resources during test..."
    
    echo "=== Node Usage ==="
    kubectl top nodes
    
    echo -e "\n=== Pod Usage ==="
    kubectl top pods -n cors-proxy
    
    echo -e "\n=== HPA Status ==="
    kubectl get hpa cors-proxy-hpa -n cors-proxy
    
    echo -e "\n=== Pod Count ==="
    kubectl get pods -n cors-proxy | grep cors-proxy | wc -l
    
    echo -e "\n=== Recent Pod Events ==="
    kubectl get events -n cors-proxy --sort-by='.lastTimestamp' | tail -10
}

# Analyze test results
analyze_results() {
    echo ""
    echo "My easter egg🥚!! Just kidding😁!!! Load Test Results are too large. Trying find a better way to analyze it in batches without frying my system!!😭"
    exit 0
    if [[ -f "$1" ]]; then
        print_status "Analyzing test results..."

        python3 <<EOF
import json

try:
    with open("$1", "r") as f:
        lines = f.readlines()

    for line in reversed(lines):
        try:
            data = json.loads(line)
            if data.get("type") == "summary":
                metrics = data.get("data", {})

                print("📊 Test Results Summary:")
                print("-" * 50)

                if "http_reqs" in metrics:
                    rate = metrics["http_reqs"].get("rate", 0)
                    count = metrics["http_reqs"].get("count", 0)
                    print(f"Total Requests: {count}")
                    print(f"Request Rate: {rate:.2f} req/s")

                if "http_req_duration" in metrics:
                    duration = metrics["http_req_duration"]
                    print(f"Avg Response Time: {duration.get('avg', 0):.2f}ms")
                    print(f"P95 Response Time: {duration.get('p(95)', 0):.2f}ms")
                    print(f"P99 Response Time: {duration.get('p(99)', 0):.2f}ms")

                if "http_req_failed" in metrics:
                    failed_rate = metrics["http_req_failed"].get("rate", 0) * 100
                    print(f"Error Rate: {failed_rate:.2f}%")

                if "data_received" in metrics:
                    data_received = metrics["data_received"].get("count", 0) / (1024 * 1024)
                    print(f"Data Received: {data_received:.2f} MB")

                break
        except json.JSONDecodeError:
            continue

except Exception as e:
    print(f"Error analyzing results: {e}")
EOF
    fi
}


# Main dispatcher
main() {
    check_k6
    get_load_balancer_url

    case "$1" in
        smoke)
            run_smoke_test
            ;;
        load)
            run_load_test
            ;;
        monitor)
            monitor_cluster
            ;;
        analyze)
            if [[ -z "$2" ]]; then
                print_error "Please provide path to results file: e.g., test-results/load-test-results-*.json"
                exit 1
            fi
            analyze_results "$2"
            ;;
        all)
            run_smoke_test && run_load_test && monitor_cluster
            ;;
        *)
            echo -e "${YELLOW}Usage: $0 {smoke|load|monitor|analyze <file>|all}${NC}"
            exit 1
            ;;
    esac
}

main "$@"
