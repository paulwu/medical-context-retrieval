# Azure Migration Guide: FAISS → Azure AI Search + Cosmos DB

## Overview

This guide documents the migration from local FAISS vector search and JSON file storage to Azure-native services (Azure AI Search + Cosmos DB).

**Migration Status**: ✅ Code migration complete, awaiting Azure credentials for testing

---

## What Has Been Completed

### 1. Configuration Updates

#### `rag/config.py`
- ✅ Added Azure AI Search configuration variables
- ✅ Added Cosmos DB container configuration
- ✅ Added `STORAGE_MODE` setting (`local` or `azure`)
- ✅ Updated exports to include new variables

#### `.env.example`
- ✅ Added Azure AI Search endpoint and key configuration
- ✅ Added Cosmos DB configuration (endpoint, key, database, containers)
- ✅ Added `STORAGE_MODE` setting with clear instructions
- ✅ Updated setup instructions

#### `requirements.txt`
- ✅ Added `azure-search-documents` for vector search
- ✅ Kept `faiss-cpu` for backward compatibility
- ✅ `azure-cosmos` already present

### 2. New Azure Integration Modules

#### `rag/azure_search.py` (NEW)
Comprehensive Azure AI Search integration:
- ✅ `create_search_index()` - Creates index with vector search capabilities
  - HNSW algorithm configuration (similar to FAISS IVF)
  - 3072-dimension vector field for text-embedding-3-large
  - Semantic search configuration for better ranking
- ✅ `upload_chunks()` - Batch upload of chunks with embeddings
- ✅ `search()` - Vector similarity search with filters
- ✅ `get_document_count()` - Check index status
- ✅ `delete_index()` - Index management

**Key Features**:
- Cosine similarity (equivalent to normalized L2 in FAISS)
- HNSW algorithm (similar performance to FAISS IVF)
- Semantic search for improved ranking
- Full-text search capabilities (bonus over FAISS)

#### `rag/azure_cosmos.py` (NEW)
Complete Cosmos DB integration for document storage:
- ✅ `init_cosmos_db()` - Initialize database and containers
- ✅ `save_documents()` / `load_documents()` - Document persistence
- ✅ `save_chunks()` / `load_chunks()` - Chunk persistence
- ✅ `get_document_by_id()` - Individual document retrieval
- ✅ `get_chunks_by_doc_id()` - Query chunks by document
- ✅ `get_stats()` - Database statistics
- ✅ Error handling and logging

**Containers**:
- `documents` - Raw ingested documents
- `chunks` - Processed chunks with headers

### 3. Updated Core Modules

#### `rag/cache.py`
- ✅ Hybrid storage support (local + Azure)
- ✅ `save_documents()` / `load_documents()` - Routes to local or Azure based on `STORAGE_MODE`
- ✅ `save_chunks()` / `load_chunks()` - Routes to local or Azure
- ✅ `build_or_load_index()` - Supports both FAISS and Azure AI Search
  - `_build_or_load_local_index()` - FAISS mode (backward compatible)
  - `_build_or_load_azure_index()` - Azure Search mode
- ✅ Conditional imports for graceful fallback
- ✅ Backward compatibility maintained

#### `rag/retrieval.py`
- ✅ `EmbeddingRetriever` class updated to support both modes
- ✅ Auto-detection of storage mode from config
- ✅ `search()` method routes to FAISS or Azure Search
- ✅ Unified interface (no breaking changes to existing code)
- ✅ Conditional imports for graceful fallback

---

## Migration Architecture

### Local Mode (Default - Backward Compatible)
```
Documents → JSON files (cache/documents.json)
Chunks → JSON files (cache/chunks.json)
Embeddings → NumPy arrays (cache/embeddings.npy)
Vector Index → FAISS (cache/faiss.index)
```

### Azure Mode (Cloud-Native)
```
Documents → Cosmos DB (documents container)
Chunks → Cosmos DB (chunks container)
Embeddings → Stored in Azure AI Search with vectors
Vector Index → Azure AI Search (managed service)
```

---

## Next Steps: Testing & Deployment

### Step 1: Get Azure Credentials

You need to retrieve the following from Azure Portal:

#### Azure AI Search
1. Go to Azure Portal → `medctx-demo-search`
2. Navigate to **Settings → Keys**
3. Copy:
   - **Endpoint**: `https://medctx-demo-search.search.windows.net`
   - **Primary Admin Key**: (copy this value)

#### Cosmos DB
1. Go to Azure Portal → `medctx-demo-cosmos`
2. Navigate to **Settings → Keys**
3. Copy:
   - **URI**: `https://medctx-demo-cosmos.documents.azure.com:443/`
   - **Primary Key**: (copy this value)

### Step 2: Update Local `.env` File

Create a `.env` file (if not exists) and add:

```bash
# Existing Azure OpenAI config (keep as-is)
AZURE_OPENAI_ENDPOINT=<your-existing-value>
AZURE_OPENAI_API_KEY=<your-existing-value>
AOAI_EMBED_MODEL=text-embedding-3-large
AOAI_CHAT_MODEL=gpt-5-mini

# NEW: Azure AI Search
AZURE_SEARCH_ENDPOINT=https://medctx-demo-search.search.windows.net
AZURE_SEARCH_KEY=<paste-admin-key-here>
AZURE_SEARCH_INDEX_NAME=medical-context-index

# NEW: Cosmos DB
COSMOS_ENDPOINT=https://medctx-demo-cosmos.documents.azure.com:443/
COSMOS_KEY=<paste-primary-key-here>
COSMOS_DB_NAME=medical-context-db
COSMOS_CONTAINER_DOCUMENTS=documents
COSMOS_CONTAINER_CHUNKS=chunks

# NEW: Storage Mode (use 'local' for testing, 'azure' for production)
STORAGE_MODE=local  # Start with local mode for testing
```

### Step 3: Install New Dependencies

```bash
pip install -r requirements.txt
```

This will install:
- `azure-search-documents` (new)
- Other dependencies (if not already installed)

### Step 4: Test Local Mode (Verify Nothing Broke)

```bash
# Run existing notebooks in local mode (default)
# This ensures backward compatibility
jupyter notebook demo.ipynb
```

Expected behavior: Should work exactly as before (using FAISS + JSON files).

### Step 5: Test Azure Mode

#### 5a. Initialize Cosmos DB

```python
from rag import azure_cosmos, config

# Set to Azure mode
import os
os.environ['STORAGE_MODE'] = 'azure'

# Initialize database and containers
azure_cosmos.init_cosmos_db()

# Verify
stats = azure_cosmos.get_stats()
print(stats)
```

#### 5b. Migrate Existing Data to Azure

Create a migration script or run in a notebook:

```python
from rag import cache, config
import os

# Step 1: Load data from local storage
os.environ['STORAGE_MODE'] = 'local'
documents = cache.load_documents()
chunks = cache.load_chunks()

print(f"Loaded {len(documents)} documents and {len(chunks)} chunks from local storage")

# Step 2: Switch to Azure mode and save
os.environ['STORAGE_MODE'] = 'azure'
cache.save_documents(documents)
cache.save_chunks(chunks)

print("Data migrated to Azure Cosmos DB")

# Step 3: Build Azure Search index
from rag.embeddings import get_embeddings_batch

texts = [c.augmented_chunk for c in chunks]
metadata = [
    {
        "chunk_id": c.chunk_id,
        "doc_id": c.doc_id,
        "doc_title": c.doc_title,
        "raw_chunk": c.raw_chunk,
        "ctx_header": c.ctx_header,
        "augmented_chunk": c.augmented_chunk,
        "section_path": c.section_path,
        "source_org": c.source_org,
        "source_url": c.source_url,
        "pub_date": c.pub_date,
        "chunk_index": c.chunk_index,
    }
    for c in chunks
]

# This will create the Azure Search index and upload all chunks
index, meta, embeddings = cache.build_or_load_index(
    texts=texts,
    metadata=metadata,
    chunks=chunks,  # Required for Azure mode
    force=True
)

print("Azure Search index built successfully")
```

#### 5c. Test Retrieval with Azure

```python
from rag.retrieval import EmbeddingRetriever

# Create retriever in Azure mode
retriever = EmbeddingRetriever(use_azure=True)

# Test search
results = retriever.search("What are the symptoms of diabetes?", top_k=5)

for result in results:
    print(f"Rank {result['rank']}: {result['similarity_score']:.3f}")
    print(f"  Title: {result['doc_title']}")
    print(f"  Snippet: {result['raw_chunk'][:100]}...")
    print()
```

### Step 6: Update Notebooks

Once Azure mode is tested and working, update notebooks:

#### `demo.ipynb` (minimal changes needed)
```python
# OLD:
from rag.cache import load_faiss_index, load_chunks
from rag.retrieval import EmbeddingRetriever

index = load_faiss_index()
chunks = load_chunks()
retriever = EmbeddingRetriever(index, chunks)

# NEW (Azure mode):
from rag.cache import load_chunks
from rag.retrieval import EmbeddingRetriever
import os

os.environ['STORAGE_MODE'] = 'azure'
retriever = EmbeddingRetriever(use_azure=True)
# That's it! Metadata comes from Azure Search automatically
```

#### `main.ipynb` (index building)
```python
# Add chunks parameter when building index in Azure mode
index, metadata, embeddings = build_or_load_index(
    texts=texts,
    metadata=metadata,
    chunks=chunks,  # NEW: Required for Azure mode
    force=False
)
```

### Step 7: Update Container App Environment Variables

Once local testing is complete, add to Container App (`medctx-demo-ca`):

```bash
AZURE_SEARCH_ENDPOINT=https://medctx-demo-search.search.windows.net
AZURE_SEARCH_KEY=<admin-key>
AZURE_SEARCH_INDEX_NAME=medical-context-index
COSMOS_ENDPOINT=https://medctx-demo-cosmos.documents.azure.com:443/
COSMOS_KEY=<primary-key>
COSMOS_DB_NAME=medical-context-db
COSMOS_CONTAINER_DOCUMENTS=documents
COSMOS_CONTAINER_CHUNKS=chunks
STORAGE_MODE=azure  # Use Azure mode in production
```

---

## Rollback Plan

If issues arise, rollback is simple:

1. Set `STORAGE_MODE=local` in environment variables
2. System automatically falls back to FAISS + JSON files
3. No code changes needed

---

## Performance Comparison

| Feature | FAISS (Local) | Azure AI Search |
|---------|---------------|-----------------|
| **Vector Search** | HNSW/IVF | HNSW (managed) |
| **Similarity** | Cosine (normalized L2) | Cosine |
| **Scaling** | Limited by memory | Automatic scaling |
| **Availability** | Single node | Geo-redundant |
| **Cost** | Compute only | Managed service fee |
| **Full-text Search** | ❌ No | ✅ Yes |
| **Semantic Search** | ❌ No | ✅ Yes |
| **Filters** | Manual in Python | Built-in OData |

---

## Cost Considerations

### Azure AI Search
- **Basic tier**: ~$75/month (recommended for dev/test)
- **Standard tier**: ~$250/month (production)
- Includes: Search queries, indexing, storage

### Cosmos DB
- **Serverless**: Pay per request (good for low traffic)
- **Provisioned**: ~$24/month for 400 RU/s (minimum)
- Current setup: Likely provisioned at 400 RU/s

### Total Estimated Cost
- **Dev/Test**: ~$100-150/month
- **Production**: ~$275-350/month

Compare to local hosting costs (compute, storage, redundancy).

---

## Benefits of Azure Migration

1. **Scalability**: Automatic scaling without infrastructure management
2. **Availability**: 99.9% SLA with geo-redundancy
3. **Security**: Managed authentication, encryption at rest
4. **Features**: Semantic search, full-text search, faceted navigation
5. **Monitoring**: Built-in Application Insights integration
6. **Deployment**: No need to copy large FAISS index files to containers
7. **Collaboration**: Shared index accessible by multiple services

---

## Troubleshooting

### "Azure modules not available"
```bash
pip install azure-search-documents azure-cosmos
```

### "FAISS not available" (in local mode)
```bash
pip install faiss-cpu
```

### Cosmos DB connection errors
- Verify endpoint URL (must include `:443/`)
- Verify primary key is correct
- Check firewall rules in Azure Portal

### Azure Search index creation fails
- Verify admin key (not query key)
- Check service tier supports vector search
- Verify index name is valid (lowercase, no special chars)

### Embeddings dimension mismatch
- Ensure `text-embedding-3-large` is used (3072 dimensions)
- If using different model, update `create_search_index(embedding_dimensions=X)`

---

## Files Modified

### Core Changes
- ✅ `rag/config.py` - Added Azure configuration
- ✅ `rag/cache.py` - Hybrid storage support
- ✅ `rag/retrieval.py` - Dual-mode retrieval
- ✅ `requirements.txt` - Added Azure SDK
- ✅ `.env.example` - Added Azure configuration template

### New Files
- ✅ `rag/azure_search.py` - Azure AI Search integration
- ✅ `rag/azure_cosmos.py` - Cosmos DB integration
- ✅ `AZURE_MIGRATION_GUIDE.md` - This document

### Files Needing Update (After Testing)
- ⏳ `demo.ipynb` - Update to use Azure mode
- ⏳ `main.ipynb` - Update index building for Azure
- ⏳ `admin.ipynb` - Add Azure management tasks
- ⏳ `README.md` - Update architecture documentation

---

## Contact & Support

For issues during migration:
1. Check Azure Portal for service health
2. Review Application Insights logs
3. Test with `STORAGE_MODE=local` for comparison
4. Check this guide's troubleshooting section

---

**Last Updated**: 2025-11-25
**Migration Version**: 1.0
**Status**: Code Complete, Awaiting Testing
