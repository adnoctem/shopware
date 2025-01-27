resource "linode_lke_cluster" "delta4x4-staging" {
  k8s_version = "1.31"
  label       = "delta4x4-staging"
  region      = "de-fra-2"
  tags = ["staging"]

  control_plane {
    high_availability = false # to be switched when prod

    # currently causes crashes, enabled via UI if at all
    # acl {
    #   enabled = false
    # }
  }

  pool {
    type  = "g6-dedicated-4"
    count = 3
  }

  pool {
    type  = "g6-standard-4"
    count = 4
  }
}

resource "linode_firewall" "default" {
  label = "kubernetes-default"

  inbound_policy  = "ACCEPT"
  outbound_policy = "ACCEPT"

  # Allow Linode infrastructure traffic as explained by Linode staff
  # This requires all services to be exposed via a Load Balancer service (e.g. the Ingress-Nginx controller)
  # ref: https://www.linode.com/community/questions/19155/securing-k8s-cluster
  inbound {
    label    = "allow-kubelet-health-checks"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "10250"
    ipv4 = ["192.168.128.0/17"]
  }

  inbound {
    label    = "allow-kubectl-wireguard-tunnel"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "51820"
    ipv4 = ["192.168.128.0/17"]
  }

  inbound {
    label    = "allow-calico-bgp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "179"
    ipv4 = ["192.168.128.0/17"]
  }

  inbound {
    label    = "allow-nodeports"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "30000-32767"
    ipv4 = ["192.168.128.0/17"]
  }

  # Drop all other traffic
  inbound {
    label    = "block-tcp-all"
    action   = "DROP"
    protocol = "TCP"
    ipv4 = ["0.0.0.0/0"]
    ipv6 = ["::/0"]
  }

  inbound {
    label    = "block-udp-all"
    action   = "DROP"
    protocol = "UDP"
    ipv4 = ["0.0.0.0/0"]
    ipv6 = ["::/0"]
  }

  inbound {
    label    = "block-icmp-all"
    action   = "DROP"
    protocol = "ICMP"
    ipv4 = ["0.0.0.0/0"]
    ipv6 = ["::/0"]
  }

  linodes = local.lke_node_ids
}