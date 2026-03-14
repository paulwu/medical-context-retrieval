# Copilot Instructions — Medical Context Retrieval

## Project Overview

A medical RAG (Retrieval-Augmented Generation) system that retrieves clinical guidelines from authoritative sources (NCI PDQ, USPSTF, NHLBI). The core innovation is **contextual header enhancement** — LLM-generated semantic headers are prepended to chunks before embedding, preserving document hierarchy that standard chunking loses. This yields measurable retrieval accuracy improvements (Precision@1: +26%, Top-3 Relevance: +24%).

The system runs in two modes controlled by `STORAGE_MODE` in `.env`:
- **Local**: FAISS vector index + JSON metadata files (in `cache/`)
- **Azure**: Azure AI Search (HNSW) + Cosmos DB

## Commands

### Setup
```bash
cp .env.example .env        # Then fill in Azure OpenAI credentials
./verify_setup.sh            # Validates Python, .env, dependencies, cache
pip install -r requirements.txt
```

### Run
```bash
./launch_demo.sh             # Voilà demo UI on http://localhost:8866
./launch_admin.sh            # Admin notebook on http://localhost:8867
voila demo.ipynb --template=lab --port=8866  # Direct launch
```

### Test
```bash
python artifacts/smoke_test.py   # Offline smoke test (no API keys needed)
```
There is no formal test suite (no pytest, no CI pipeline). The smoke test validates module imports, FAISS index building, and retriever search using synthetic embeddings.

### Deploy to Azure
```bash
cd infrastructure && terraform init && terraform plan && terraform apply  # Create Azure resources
./package.sh          # Build container image, push to ACR
./update.sh           # Deploy new image to Container App
```

### Infrastructure
```bash
cd infrastructure
terraform fmt -recursive     # Format
terraform validate           # Syntax check
terraform plan -out=tfplan   # Preview changes
terraform apply tfplan       # Apply
```

## Architecture

### RAG Pipeline
```
data_pilot/ (JSON docs)  →  chunking.py (semantic ~300-word chunks)
                          →  headers.py (async LLM contextual headers)
                          →  embeddings.py (Azure OpenAI text-embedding-3-large, 3072-dim)
                          →  cache.py (FAISS+JSON local  OR  Azure Search+Cosmos DB)
                          →  retrieval.py (EmbeddingRetriever — unified interface for both backends)
```

### Key Modules in `rag/`

| Module | Role |
|--------|------|
| `config.py` | Central config — reads `.env`, exposes all settings as module-level constants |
| `models.py` | `Document` and `Chunk` dataclasses |
| `chunking.py` | `SemanticChunker` — splits docs at paragraph boundaries |
| `headers.py` | `generate_headers()` — async LLM header generation with rate limiting (the core innovation) |
| `embeddings.py` | `get_embeddings_batch()` — Azure OpenAI wrapper with exponential backoff |
| `index.py` | `build_faiss_index()` — creates FAISS Flat or IVF indices with L2 normalization |
| `retrieval.py` | `EmbeddingRetriever` — unified search across FAISS and Azure AI Search |
| `cache.py` | Dual-mode persistence (local files vs Azure services) |
| `azure_search.py` | Azure AI Search index creation, chunk upload, vector search |
| `azure_cosmos.py` | Cosmos DB document/chunk storage |
| `ingestion.py` | Loads JSON/PDF documents from `data_pilot/` |
| `scrape.py` | Web scraping for new medical guidelines |

### Infrastructure (`infrastructure/`)

Terraform modules provision: Azure AI Search, Cosmos DB, Container Apps, AI Foundry, Key Vault, VNet with private endpoints, API Management, and Front Door.

### Entry Points

- **`demo.ipynb`** — User-facing Voilà search interface with mode toggle (local/Azure), confidence-scored results, and source citations
- **`admin.ipynb`** — System management: index building, data ingestion, scraping, evaluation
- **Migration scripts** at repo root: `migrate_to_cosmos.py`, `migrate_to_azure.py`, `create_azure_search_index.py`, `populate_azure_search.py`

## Conventions

### Configuration
- All runtime config flows through `rag/config.py` which reads `.env` via `python-dotenv`. Import `config` instead of calling `os.getenv` directly in other modules.
- `config.PROJECT_ROOT`, `config.DATA_DIR`, `config.CACHE_DIR` are canonical path references.

### Code Style
- Python 3.11+, `from __future__ import annotations` used throughout
- Type hints on all public functions
- Async/await for I/O-bound operations (header generation, embedding calls)
- Exponential backoff for Azure OpenAI rate limits
- `EmbeddingRetriever` auto-detects storage mode — same interface regardless of backend

### Embedding Dimensions
Embeddings are **3072-dimensional** (text-embedding-3-large). This is hardcoded in the Azure Search index schema and expected by FAISS index builders.

### Data Format
Documents in `data_pilot/` are JSON with fields: `doc_title`, `text`, `source_url`, `source_org`, `pub_date`. Filenames are UUIDs.

### Docker
The container runs Voilà on port 8866 with `python:3.11-slim` base. Cache artifacts must be pre-populated before building the image for fast startup.

### Git Workflow
Trunk-based development. Two contributors: Paul Wu (infrastructure), Brendon Colburn (RAG core).
