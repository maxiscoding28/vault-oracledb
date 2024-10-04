listener "tcp" {
    address = "0.0.0.0:8200"
    cluster_address = "0.0.0.0:8201"
    tls_disable = 1
}
  
storage "raft" {
    path = "/opt/vault/data"
    node_id = "v0"
}

api_addr = "http://v0:8200"
cluster_addr = "http://v0:8201"
cluster_name = "v-cluster"
ui = true
log_level = "info"
raw_storage_endpoint = true
disable_performance_standby = false
plugin_directory="/vault/plugin/vault-plugin-database-oracle"
disable_mlock = true

