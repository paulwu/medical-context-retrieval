---
name: microsoft-docs
description: Query official Microsoft documentation to understand concepts, find tutorials, and learn how services work. Use for Azure, .NET, Microsoft 365, Windows, Power Platform, and all Microsoft technologies. Get accurate, current information from learn.microsoft.com and other official Microsoft websites—architecture overviews, quickstarts, configuration guides, limits, and best practices.
compatibility: Uses fetch_webpage tool to access Microsoft Learn at https://learn.microsoft.com. For full MCP support, install Microsoft Learn MCP Server from https://github.com/microsoftdocs/mcp (npx -y @microsoftdocs/mcp)
---

# Microsoft Docs

## Tools

| Tool | Use For |
|------|---------|
| `fetch_webpage` | Search and retrieve Microsoft documentation pages from learn.microsoft.com |
| `semantic_search` | Search codebase for Azure/Microsoft implementation patterns |

## When to Use

- **Understanding concepts** — "How does Cosmos DB partitioning work?"
- **Learning a service** — "Azure Functions overview", "Container Apps architecture"
- **Finding tutorials** — "quickstart", "getting started", "step-by-step"
- **Configuration options** — "App Service configuration settings"
- **Limits & quotas** — "Azure OpenAI rate limits", "Service Bus quotas"
- **Best practices** — "Azure security best practices"

## Query Effectiveness

Good queries are specific:

```
# ❌ Too broad
"Azure Functions"

# ✅ Specific
"Azure Functions Python v2 programming model"
"Cosmos DB partition key design best practices"
"Container Apps scaling rules KEDA"
```

Include context:
- **Version** when relevant (`.NET 8`, `EF Core 8`)
- **Task intent** (`quickstart`, `tutorial`, `overview`, `limits`)
- **Platform** for multi-platform docs (`Linux`, `Windows`)

## When to Fetch Full Page

Fetch after search when:
- **Tutorials** — need complete step-by-step instructions
- **Configuration guides** — need all options listed
- **Deep dives** — user wants comprehensive coverage
- **Search excerpt is cut off** — full context needed

## Why Use This

- **Accuracy** — live docs, not training data that may be outdated
- **Completeness** — tutorials have all steps, not fragments
- **Authority** — official Microsoft documentation
