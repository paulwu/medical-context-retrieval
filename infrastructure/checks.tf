# ══════════════════════════════════════════════════════════════
# Cost Warnings — terraform plan / apply warnings for expensive resources
# ══════════════════════════════════════════════════════════════
#
# Terraform check blocks produce warnings (not errors) during plan.
# They alert the operator when expensive optional resources are enabled.

check "ai_search_cost_warning" {
  assert {
    condition     = !var.deploy_ai_search
    error_message = "⚠️  COST WARNING: AI Search is enabled. Standard SKU costs ~$250/mo, Basic ~$75/mo. Use 'free' for dev/test if possible."
  }
}

check "cosmos_db_cost_warning" {
  assert {
    condition     = !var.deploy_infrastructure
    error_message = "⚠️  COST NOTE: Cosmos DB is deployed with provisioned throughput. Each container at 400 RU/s costs ~$24/mo. Review cosmos_db_containers for unused containers."
  }
}

check "container_registry_premium_warning" {
  assert {
    condition = !var.deploy_infrastructure || (
      var.deploy_infrastructure && var.container_registry_sku != "Premium"
    )
    error_message = "⚠️  COST WARNING: Container Registry SKU is 'Premium' (~$50/mo + $50/geo-replica). Basic (~$5/mo) or Standard (~$20/mo) may be sufficient for dev/test."
  }
}

check "front_door_cost_warning" {
  assert {
    condition     = !var.deploy_azure_frontdoor
    error_message = "⚠️  COST WARNING: Azure Front Door is enabled. Standard SKU costs ~$35/mo base, Premium ~$330/mo. Ensure this is needed for your deployment."
  }
}

check "ai_foundry_cost_warning" {
  assert {
    condition     = !var.deploy_ai_foundry_instances
    error_message = "⚠️  COST NOTE: AI Foundry instances are being deployed. Model deployments incur per-token charges. Review model SKUs and rate limits."
  }
}

check "private_network_cost_warning" {
  assert {
    condition     = !var.deploy_private_network
    error_message = "⚠️  COST NOTE: Private networking is enabled. Each private endpoint costs ~$7.30/mo. With ${length(keys(local.all_private_endpoints))} endpoints, that's ~$${length(keys(local.all_private_endpoints)) * 7}/mo."
  }
}

check "key_vault_premium_warning" {
  assert {
    condition     = !var.deploy_infrastructure || var.key_vault_sku != "premium"
    error_message = "⚠️  COST NOTE: Key Vault Premium SKU is selected (~$5/mo vs ~$1/mo for Standard). Premium is only needed for HSM-backed keys."
  }
}

check "storage_replication_warning" {
  assert {
    condition = !var.deploy_infrastructure || (
      var.deploy_infrastructure && contains(["LRS", "ZRS"], var.storage_account_replication_type)
    )
    error_message = "⚠️  COST NOTE: Storage replication is '${var.storage_account_replication_type}'. GRS/RAGRS doubles storage cost. LRS is sufficient for dev/test."
  }
}
