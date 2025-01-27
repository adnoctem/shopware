output "kubeconfig" {
  value       = linode_lke_cluster.delta4x4-staging.kubeconfig
  description = "The kubeconfig configuration file for kubectl access"
  sensitive   = true
}