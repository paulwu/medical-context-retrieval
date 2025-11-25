# Azure Search Indexer Setup - Cloud Shell Instructions

## Quick Setup (5 minutes)

Open Azure Cloud Shell: https://shell.azure.com

### Option 1: Upload and Run Python Script (Recommended)

1. Upload `setup_cosmos_indexer.py` using the upload button
2. Install dependencies:
```bash
pip install --user azure-search-documents azure-cosmos python-dotenv
```

3. Upload your `.env` file (or set variables directly):
```bash
export COSMOS_ENDPOINT="https://<your-cosmos-account>.documents.azure.com:443/"
export COSMOS_DB_NAME="medical-context-db"
export COSMOS_CONTAINER_CHUNKS="chunks"

export AZURE_SEARCH_ENDPOINT="https://<your-search-service>.search.windows.net"
export AZURE_SEARCH_INDEX_NAME="medical-context-index"

export AZURE_OPENAI_ENDPOINT="https://<your-aoai-account>.cognitiveservices.azure.com/"
export AOAI_EMBED_MODEL="text-embedding-3-large"
export STORAGE_MODE="azure"

# IMPORTANT: do not paste secrets into files.
# Fetch keys via Azure CLI at runtime and export them in your shell session.

# Cosmos DB key
export COSMOS_KEY="$(az cosmosdb keys list -g <rg> -n <cosmos-account> --type keys --query primaryMasterKey -o tsv)"

# Azure AI Search admin key
export AZURE_SEARCH_KEY="$(az search admin-key show -g <rg> --service-name <search-service> --query primaryKey -o tsv)"

# Azure OpenAI key
export AZURE_OPENAI_API_KEY="$(az cognitiveservices account keys list -g <rg> -n <aoai-account> --query key1 -o tsv)"
```

4. Run the setup:
```bash
python3 setup_cosmos_indexer.py
```

5. Monitor progress:
```bash
# Wait a few minutes, then check status
python3 check_indexer_status.py
```

### Option 2: Use Azure Portal (GUI)

1. **Create Data Source**:
   - Go to Azure Portal → Your Search Service → Data sources → Add
   - Type: Azure Cosmos DB
   - Name: `cosmos-chunks-datasource`
   - Connection string: `AccountEndpoint=<COSMOS_ENDPOINT>;AccountKey=<COSMOS_KEY>;Database=medical-context-db`
   - Container: `chunks`
   - Query: (leave empty)

2. **Create Index** (use the schema from setup script, or import from portal)

3. **Create Skillset**:
   - Add skill: Azure OpenAI Embedding
   - Resource URI: `https://brend-mfh6fonr-eastus2.cognitiveservices.azure.com/`
   - Deployment: `text-embedding-3-large`
   - Input: `augmented_chunk`
   - Output: `embedding`

4. **Create Indexer**:
   - Connect data source to index
   - Attach skillset
   - Field mappings: Auto-map by name
   - Run immediately

## What Happens Next

The indexer will:
1. Pull all 762 chunks from Cosmos DB
2. Generate embeddings using Azure OpenAI (via skillset)
3. Index them in Azure Search
4. **Time: ~10-15 minutes for initial indexing**

## Monitor Progress

Check indexer status in Azure Portal:
- Search Service → Indexers → `cosmos-chunks-indexer`
- Shows progress, errors, completion status

Or use the status checker script:
```bash
python3 check_indexer_status.py
```

## Troubleshooting

**"Failed to connect to Cosmos DB"**
- Verify connection string includes `;Database=medical-context-db`
- Check firewall allows Azure services

**"Skillset errors"**
- Verify Azure OpenAI key and endpoint
- Check deployment name matches `text-embedding-3-large`

**"Index already exists"**
- Delete existing index first, or use update mode

## Next Steps

Once indexer completes (762/762 chunks):
1. Test retrieval: `python3 test_azure_retrieval.py`
2. Update notebooks with educational walkthrough
3. Deploy to production
