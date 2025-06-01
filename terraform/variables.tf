# variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "cors-proxy-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["m5.large", "m5.xlarge"]
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 10
}

# Instance types
variable "on_demand_instance_type" {
  default = "m5.large"
}
variable "spot_instance_types" {
  type    = list(string)
  default = ["t3.large", "m5.large", "m5a.large"]
}

# AMI
variable "ami_type" {
  default = "AL2_x86_64"
}

# Disk size
variable "node_disk_size" {
  default = 20
}

# Scaling configs for on-demand
variable "on_demand_desired" {
  default = 2
}
variable "on_demand_max" {
  default = 3
}
variable "on_demand_min" {
  default = 2
}
variable "on_demand_max_unavailable" {
  default = 25
}

# Scaling configs for spot
variable "spot_desired" {
  default = 0
}
variable "spot_max" {
  default = 5
}
variable "spot_min" {
  default = 0
}
variable "spot_max_unavailable" {
  default = 50
}

# Node group names
variable "on_demand_node_group_name" {
  default = "cors-proxy-on-demand"
}
variable "spot_node_group_name" {
  default = "cors-proxy-spot"
}

# Labels
variable "on_demand_node_labels" {
  default = {
    "node-type" = "on-demand"
    "workload"  = "cors-proxy"
  }
}
variable "spot_node_labels" {
  default = {
    "node-type" = "spot"
    "workload"  = "cors-proxy"
  }
}

# Common tags
variable "common_tags" {
  default = {
    Environment                               = "production"
    "k8s.io/cluster-autoscaler/enabled"       = "true"
  }
}
