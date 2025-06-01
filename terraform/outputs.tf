# outputs.tf
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# output "node_groups" {
#   description = "EKS node groups"
#   value       = aws_eks_node_group.main.arn
# }

output "vpc_id" {
  description = "ID of the VPC where the cluster and workers are deployed"
  value       = aws_vpc.main.id
}

output "load_balancer_hostname" {
  description = "Load balancer hostname for the CORS proxy service"
  value       = "Run 'kubectl get ingress cors-proxy-ingress -n cors-proxy' to get the ALB hostname"
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${var.cluster_name}"
}

output "on_demand_node_group_arn" {
  description = "ARN of the on-demand node group"
  value       = aws_eks_node_group.cors_proxy_on_demand.arn
}

output "cors_proxy_namespace" {
  description = "The namespace where the CORS Proxy is deployed"
  value       = kubernetes_namespace.cors_proxy.metadata[0].name
}


output "spot_node_group_arn" {
  description = "ARN of the spot node group"
  value       = aws_eks_node_group.cors_proxy_spot.arn
}

output "aws_region" {
  description = "Terraform Region"
  value       = var.aws_region
}
