# ══════════════════════════════════════════════════════════════
# Cost Metadata — Estimated monthly USD costs per module/SKU
# ══════════════════════════════════════════════════════════════
#
# These estimates are Azure pay-as-you-go list prices (USD/month)
# as of 2026-03. Actual costs vary by region, reserved instances,
# and consumption. Use these for planning and Copilot cost queries.
#
# Copilot: to estimate total monthly cost, sum the enabled modules
# using the current SKU values from terraform.tfvars.

locals {
  cost_estimates = {
    # ── Core infrastructure (always deployed) ─────────────

    storage = {
      description = "Azure Storage Account (blob, table, queue)"
      skus = {
        "Standard_LRS"   = { monthly_usd = 5, notes = "Locally redundant" }
        "Standard_GRS"   = { monthly_usd = 10, notes = "Geo-redundant" }
        "Standard_RAGRS" = { monthly_usd = 12, notes = "Read-access geo-redundant" }
        "Standard_ZRS"   = { monthly_usd = 8, notes = "Zone-redundant" }
        "Premium_LRS"    = { monthly_usd = 35, notes = "Premium SSD" }
      }
    }

    key_vault = {
      description = "Azure Key Vault"
      skus = {
        "standard" = { monthly_usd = 1, notes = "$0.03/10K operations" }
        "premium"  = { monthly_usd = 5, notes = "HSM-backed keys available" }
      }
    }

    cosmos_db = {
      description = "Azure Cosmos DB (SQL API) — per container at provisioned throughput"
      skus = {
        "400_RU"  = { monthly_usd = 24, notes = "400 RU/s provisioned — per container" }
        "1000_RU" = { monthly_usd = 58, notes = "1000 RU/s provisioned — per container" }
        "4000_RU" = { monthly_usd = 233, notes = "4000 RU/s provisioned — per container" }
      }
    }

    container_registry = {
      description = "Azure Container Registry"
      skus = {
        "Basic"    = { monthly_usd = 5, notes = "10GB storage" }
        "Standard" = { monthly_usd = 20, notes = "100GB storage" }
        "Premium"  = { monthly_usd = 50, notes = "500GB, geo-replication (+$50/replica)" }
      }
    }

    application_insights = {
      description = "Application Insights (Log Analytics-based)"
      skus = {
        "default" = { monthly_usd = 0, notes = "Free up to 5GB/mo ingestion, then $2.30/GB" }
      }
    }

    # ── Optional services ─────────────────────────────────

    container_app = {
      description = "Azure Container Apps Environment"
      skus = {
        "Consumption" = { monthly_usd = 0, notes = "Pay per vCPU-sec and GiB-sec" }
      }
    }

    ai_search = {
      description = "Azure AI Search"
      skus = {
        "free"      = { monthly_usd = 0, notes = "3 indexes, 50MB storage" }
        "basic"     = { monthly_usd = 75, notes = "15GB, 5 indexes" }
        "standard"  = { monthly_usd = 250, notes = "50GB, 50 indexes — recommended for production" }
        "standard2" = { monthly_usd = 500, notes = "200GB, 200 indexes" }
        "standard3" = { monthly_usd = 1000, notes = "1TB, 1000 indexes" }
      }
    }

    ai_foundry = {
      description = "Azure AI Foundry (Cognitive Services) — base account cost"
      skus = {
        "S0" = { monthly_usd = 0, notes = "Pay-per-use; model deployment costs vary by token usage" }
      }
    }

    ai_model_gpt4 = {
      description = "GPT-4o model deployment (per 1M tokens)"
      skus = {
        "GlobalStandard" = { monthly_usd = 0, notes = "Input: $2.50/1M, Output: $10/1M tokens" }
      }
    }

    ai_model_embedding = {
      description = "text-embedding-3-large model deployment (per 1M tokens)"
      skus = {
        "GlobalStandard" = { monthly_usd = 0, notes = "Input: $0.13/1M tokens" }
      }
    }

    front_door = {
      description = "Azure Front Door"
      skus = {
        "Standard_AzureFrontDoor" = { monthly_usd = 35, notes = "Standard CDN + routing" }
        "Premium_AzureFrontDoor"  = { monthly_usd = 330, notes = "Includes WAF + private link" }
      }
    }

    private_endpoint = {
      description = "Private Endpoint (per endpoint)"
      skus = {
        "default" = { monthly_usd = 7, notes = "$7.30/mo per endpoint + data processing $0.01/GB" }
      }
    }

    vnet = {
      description = "Virtual Network"
      skus = {
        "default" = { monthly_usd = 0, notes = "Free; peering costs $0.01/GB transferred" }
      }
    }
  }
}
