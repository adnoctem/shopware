locals {
  lke_node_ids = flatten(
    concat(
      [for n in linode_lke_cluster.delta4x4-staging.pool[0].nodes : n.instance_id],
      [for n in linode_lke_cluster.delta4x4-staging.pool[1].nodes : n.instance_id]
    )
  )
}