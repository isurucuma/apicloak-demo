# GKE Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
}

variable "zone" {
  description = "GCP zone for the cluster"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet for GKE nodes"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary IP range for pods"
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary IP range for services"
  type        = string
}
