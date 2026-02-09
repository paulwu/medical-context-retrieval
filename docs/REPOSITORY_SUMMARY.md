# Repository Analysis: Medical Context Retrieval System

## Overview

This repository implements a specialized Retrieval-Augmented Generation (RAG) system designed for medical guideline search. Unlike generic RAG implementations, this system features a proprietary **contextual header enhancement** technique that addresses the unique challenges of medical information retrieval—where context loss during document chunking can lead to incomplete or misleading clinical information.

The system addresses a critical problem in healthcare AI: when medical documents are split into chunks for vector search, they lose essential context (like which medication, patient population, or disease stage the information applies to). This system solves this by generating semantic headers that preserve hierarchical document context.

## Architecture

The system employs a **hybrid architecture** supporting two operational modes:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Medical Context Retrieval System                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐   │
│  │   Documents  │───>│  Chunking +  │───>│  Vector Embeddings       │   │
│  │  (NCI, USPSTF│    │  Header Gen  │    │  (text-embedding-3-large)│   │
│  │   NHLBI)     │    └──────────────┘    └──────────────────────────┘   │
│  └──────────────┘                                   │                   │
│                                                     ▼                   │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                      Storage Mode Switch                           │ │
│  │  ┌─────────────────────┐    ┌─────────────────────────────────┐    │ │
│  │  │   LOCAL MODE        │    │   AZURE MODE                    │    │ │
│  │  │   • FAISS Index     │    │   • Azure AI Search (HNSW)      │    │ │
│  │  │   • JSON Files      │ OR │   • Azure Cosmos DB             │    │ │
│  │  │   • Local Cache     │    │   • Cloud-scale infrastructure  │    │ │
│  │  └─────────────────────┘    └─────────────────────────────────┘    │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                     │                   │
│                                                     ▼                   │
│  ┌──────────────────┐    ┌──────────────────────────────────────────┐   │
│  │  Query Input     │───>│  EmbeddingRetriever (unified interface)  │   │
│  └──────────────────┘    └──────────────────────────────────────────┘   │
│                                                     │                   │
│                                                     ▼                   │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Interactive Demo (Voilà + ipywidgets)                           │   │
│  │  • Color-coded confidence scores • Source citations • Examples   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Directory Structure

| Directory | Purpose |
|-----------|---------|
| `rag/` | Core RAG system modules (Python) |
| `infrastructure/` | Terraform IaC for Azure deployment |
| `data_pilot/` | Source medical documents (JSON + PDFs) |
| `cache/` | Local FAISS index and chunk cache |
| `voila_config/` | Healthcare-themed UI styling |
| `examples/` | Sample queries for demos |
| `artifacts/` | Benchmark results and test artifacts |

## Key Components

### 1. **RAG Core (`rag/`)**
- **config.py**: Central configuration loading from `.env`, supporting both local and Azure modes
- **embeddings.py**: Azure OpenAI embedding utilities with batched generation
- **headers.py**: Proprietary contextual header generation with async rate limiting (468 lines)
- **chunking.py**: Semantic boundary-aware document chunking
- **retrieval.py**: Unified `EmbeddingRetriever` class supporting FAISS and Azure AI Search
- **azure_search.py**: Azure AI Search integration module
- **azure_cosmos.py**: Cosmos DB document storage integration
- **scrape.py**: Web scraping utilities for guideline ingestion

### 2. **Infrastructure as Code (`infrastructure/`)**
- **main.tf**: Root Terraform configuration for Azure deployment
- **modules/**: Modular components for:
  - `ai_foundry/`: Azure AI Foundry configuration
  - `ai_search/`: Azure AI Search with HNSW vector index
  - `container_app_environment/`: Container Apps for hosting
  - `key_vault/`: Secrets management
  - `private_network/`, `vnet/`, `private_dns_zone/`: Secure networking
  - `apim/`: API Management (optional)
  - `azure_frontdoor/`: CDN and global routing

### 3. **Interactive Demo**
- **demo.ipynb**: Customer-facing demo notebook (clean UI)
- **admin.ipynb**: Administrative/development notebook
- **voila_config/**: Custom healthcare-themed CSS styling

### 4. **Evaluation & Benchmarking (`rag/eval/`)**
- **benchmark.py**: Performance benchmarking framework
- **metrics.py**: Retrieval accuracy metrics (MRR, Recall@K, etc.)

## Technologies Used

### Core Languages & Frameworks
- **Python 3.x**: Primary language
- **Jupyter/Voilà**: Interactive demo interface
- **ipywidgets**: UI components

### AI/ML
- **Azure OpenAI**: `text-embedding-3-large` for embeddings, GPT models for chat
- **FAISS**: Facebook AI Similarity Search (local mode)
- **Azure AI Search**: Cloud vector search with HNSW algorithm

### Cloud Infrastructure
- **Terraform**: Infrastructure as Code
- **Azure Container Apps**: Application hosting
- **Azure Cosmos DB**: Document/chunk storage
- **Azure Key Vault**: Secrets management
- **Azure Front Door**: CDN and global routing (optional)
- **Azure API Management**: API gateway (optional)

### DevOps
- **Dev Containers**: Consistent development environment
- **Git**: Version control
- **GitHub**: Repository hosting

## Data Flow

1. **Ingestion**: Medical guidelines (NCI PDQ, USPSTF, NHLBI) are scraped and stored
2. **Chunking**: Documents split at semantic boundaries (max 300 words)
3. **Header Generation**: LLM generates contextual headers preserving document hierarchy
4. **Embedding**: Chunks + headers embedded using Azure OpenAI
5. **Indexing**: Vectors stored in FAISS (local) or Azure AI Search (cloud)
6. **Query**: User query embedded and similarity search performed
7. **Retrieval**: Top-K relevant chunks returned with confidence scores
8. **Display**: Results shown with color-coded relevance and source citations

## Team and Ownership

Based on commit history analysis:

| Area | Primary Owner | Commits | Focus |
|------|---------------|---------|-------|
| Infrastructure (Terraform) | **Paul Wu** | 14 | Azure deployment, IaC modules |
| RAG Core (Python) | **Brendon Colburn** | 7 | Retrieval logic, headers, chunking |
| DevContainer & Config | Both | Shared | Development environment setup |
| Documentation | Both | Shared | README, DEMO_GUIDE, guides |

**Total Contributors**: 2 active contributors
**Repository Created**: September 18, 2025
**Last Activity**: February 9, 2026
