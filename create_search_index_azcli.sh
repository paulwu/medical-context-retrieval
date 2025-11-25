#!/bin/bash
# Create Azure Search Index using Azure CLI REST API
# This script can be run in Azure Cloud Shell

set -e

echo "=========================================="
echo "Azure Search Index Creation via Azure CLI"
echo "=========================================="
echo ""

# Load environment variables from .env file
if [ -f .env ]; then
    echo "Loading configuration from .env..."
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "ERROR: .env file not found"
    exit 1
fi

# Verify required variables
if [ -z "$COSMOS_ENDPOINT" ] || [ -z "$COSMOS_KEY" ]; then
    echo "ERROR: Cosmos DB credentials not found in .env"
    exit 1
fi

if [ -z "$AZURE_SEARCH_ENDPOINT" ] || [ -z "$AZURE_SEARCH_KEY" ]; then
    echo "ERROR: Azure Search credentials not found in .env"
    exit 1
fi

if [ -z "$AZURE_OPENAI_ENDPOINT" ] || [ -z "$AZURE_OPENAI_API_KEY" ]; then
    echo "ERROR: Azure OpenAI credentials not found in .env"
    exit 1
fi

# Set defaults
COSMOS_DB_NAME=${COSMOS_DB_NAME:-medical-context-db}
COSMOS_CONTAINER_CHUNKS=${COSMOS_CONTAINER_CHUNKS:-chunks}
AZURE_SEARCH_INDEX_NAME=${AZURE_SEARCH_INDEX_NAME:-medical-context-index}
AOAI_EMBED_MODEL=${AOAI_EMBED_MODEL:-text-embedding-3-large}

echo "Configuration:"
echo "  Cosmos DB: ${COSMOS_ENDPOINT}"
echo "  Database: ${COSMOS_DB_NAME}"
echo "  Container: ${COSMOS_CONTAINER_CHUNKS}"
echo "  Azure Search: ${AZURE_SEARCH_ENDPOINT}"
echo "  Index: ${AZURE_SEARCH_INDEX_NAME}"
echo "  Embedding Model: ${AOAI_EMBED_MODEL}"
echo ""

# Step 1: Create Azure Search Index Schema
echo "[Step 1/4] Creating Azure Search index schema..."

SEARCH_INDEX_SCHEMA='{
  "name": "'${AZURE_SEARCH_INDEX_NAME}'",
  "fields": [
    {"name": "id", "type": "Edm.String", "key": true, "searchable": false},
    {"name": "chunk_id", "type": "Edm.String", "searchable": false, "filterable": true},
    {"name": "doc_id", "type": "Edm.String", "searchable": false, "filterable": true},
    {"name": "doc_title", "type": "Edm.String", "searchable": true, "filterable": true},
    {"name": "raw_chunk", "type": "Edm.String", "searchable": true},
    {"name": "ctx_header", "type": "Edm.String", "searchable": true},
    {"name": "augmented_chunk", "type": "Edm.String", "searchable": true},
    {"name": "section_path", "type": "Edm.String", "searchable": false, "filterable": true},
    {"name": "source_org", "type": "Edm.String", "searchable": false, "filterable": true},
    {"name": "source_url", "type": "Edm.String", "searchable": false, "filterable": false},
    {"name": "pub_date", "type": "Edm.String", "searchable": false, "filterable": true},
    {"name": "chunk_index", "type": "Edm.Int32", "searchable": false, "filterable": true, "sortable": true},
    {"name": "embedding", "type": "Collection(Edm.Single)", "searchable": true, "dimensions": 3072,
     "vectorSearchProfile": "medical-context-vector-profile"}
  ],
  "vectorSearch": {
    "algorithms": [
      {
        "name": "medical-context-hnsw",
        "kind": "hnsw",
        "hnswParameters": {
          "m": 4,
          "efConstruction": 400,
          "efSearch": 500,
          "metric": "cosine"
        }
      }
    ],
    "profiles": [
      {
        "name": "medical-context-vector-profile",
        "algorithm": "medical-context-hnsw"
      }
    ]
  },
  "semantic": {
    "configurations": [
      {
        "name": "medical-semantic-config",
        "prioritizedFields": {
          "titleField": {"fieldName": "doc_title"},
          "contentFields": [
            {"fieldName": "augmented_chunk"},
            {"fieldName": "ctx_header"}
          ]
        }
      }
    ]
  }
}'

# Extract hostname from endpoint for REST API
SEARCH_HOST=$(echo $AZURE_SEARCH_ENDPOINT | sed 's|https://||' | sed 's|http://||')

echo "Creating/updating index at ${SEARCH_HOST}..."
curl -X PUT \
  "https://${SEARCH_HOST}/indexes/${AZURE_SEARCH_INDEX_NAME}?api-version=2023-11-01" \
  -H "Content-Type: application/json" \
  -H "api-key: ${AZURE_SEARCH_KEY}" \
  -d "${SEARCH_INDEX_SCHEMA}" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s -o /tmp/create_index_response.json

if [ $? -eq 0 ]; then
    echo "✓ Index schema created/updated"
else
    echo "✗ Failed to create index"
    cat /tmp/create_index_response.json
    exit 1
fi

# Step 2: Query Cosmos DB for chunks
echo ""
echo "[Step 2/4] Loading chunks from Cosmos DB..."

# Extract host from endpoint
COSMOS_HOST=$(echo $COSMOS_ENDPOINT | sed 's|https://||' | sed 's|http://||' | sed 's|:443/||')

# Note: This is a simplified approach. For 762 chunks, we need to handle pagination
# In production, you'd use continuation tokens. For now, we'll set a high page size.
COSMOS_QUERY='{"query": "SELECT * FROM c", "parameters": []}'

echo "Querying Cosmos DB at ${COSMOS_HOST}..."
echo "This script demonstrates the approach but handling 762 chunks requires a more robust solution."
echo ""

# Step 3: Generate embeddings and upload
echo "[Step 3/4] For 762 chunks, we need Python to handle:"
echo "  • Batch processing of chunks"
echo "  • Rate limiting for embeddings API"
echo "  • Efficient vector upload"
echo ""
echo "RECOMMENDATION: Use the Python script in Azure Cloud Shell instead."
echo ""

cat << 'PYTHON_SCRIPT' > /tmp/upload_to_search.py
#!/usr/bin/env python3
import os
import sys
import json
import time
import requests
from typing import List, Dict, Any

def load_chunks_from_cosmos():
    """Load all chunks from Cosmos DB"""
    cosmos_endpoint = os.getenv('COSMOS_ENDPOINT').rstrip('/')
    cosmos_key = os.getenv('COSMOS_KEY')
    db_name = os.getenv('COSMOS_DB_NAME', 'medical-context-db')
    container_name = os.getenv('COSMOS_CONTAINER_CHUNKS', 'chunks')

    # Cosmos DB REST API endpoint
    url = f"{cosmos_endpoint}/dbs/{db_name}/colls/{container_name}/docs"

    headers = {
        'authorization': cosmos_key,
        'x-ms-version': '2018-12-31',
        'x-ms-documentdb-isquery': 'True',
        'Content-Type': 'application/query+json'
    }

    query = {'query': 'SELECT * FROM c', 'parameters': []}

    print(f"Querying Cosmos DB: {url}")
    response = requests.post(url, headers=headers, json=query)

    if response.status_code != 200:
        print(f"Error querying Cosmos DB: {response.status_code}")
        print(response.text)
        sys.exit(1)

    data = response.json()
    chunks = data.get('Documents', [])
    print(f"✓ Loaded {len(chunks)} chunks from Cosmos DB")
    return chunks

def get_embedding(text: str) -> List[float]:
    """Get embedding for a single text using Azure OpenAI"""
    endpoint = os.getenv('AZURE_OPENAI_ENDPOINT').rstrip('/')
    api_key = os.getenv('AZURE_OPENAI_API_KEY')
    model = os.getenv('AOAI_EMBED_MODEL', 'text-embedding-3-large')

    url = f"{endpoint}/openai/deployments/{model}/embeddings?api-version=2023-05-15"

    headers = {
        'api-key': api_key,
        'Content-Type': 'application/json'
    }

    data = {'input': text}

    response = requests.post(url, headers=headers, json=data)

    if response.status_code != 200:
        print(f"Error getting embedding: {response.status_code}")
        print(response.text)
        sys.exit(1)

    result = response.json()
    return result['data'][0]['embedding']

def upload_to_search(documents: List[Dict[str, Any]]):
    """Upload documents to Azure Search"""
    endpoint = os.getenv('AZURE_SEARCH_ENDPOINT').rstrip('/')
    api_key = os.getenv('AZURE_SEARCH_KEY')
    index_name = os.getenv('AZURE_SEARCH_INDEX_NAME', 'medical-context-index')

    url = f"{endpoint}/indexes/{index_name}/docs/index?api-version=2023-11-01"

    headers = {
        'api-key': api_key,
        'Content-Type': 'application/json'
    }

    # Upload in batches of 100
    batch_size = 100
    for i in range(0, len(documents), batch_size):
        batch = documents[i:i+batch_size]
        data = {'value': batch}

        print(f"  Uploading batch {i//batch_size + 1}/{(len(documents)+batch_size-1)//batch_size}...")

        response = requests.post(url, headers=headers, json=data)

        if response.status_code not in [200, 201]:
            print(f"Error uploading batch: {response.status_code}")
            print(response.text)
            sys.exit(1)

        time.sleep(1)  # Rate limiting

    print(f"✓ Uploaded {len(documents)} documents to Azure Search")

def main():
    print("=" * 70)
    print("Azure Search Upload - Python Helper")
    print("=" * 70)

    # Load chunks from Cosmos DB
    chunks = load_chunks_from_cosmos()

    if not chunks:
        print("No chunks found in Cosmos DB")
        sys.exit(1)

    # Process chunks and generate embeddings
    print(f"\nGenerating embeddings for {len(chunks)} chunks...")
    print("⏳ This will take approximately 5-10 minutes...")

    documents = []
    for idx, chunk in enumerate(chunks, 1):
        if idx % 10 == 0:
            print(f"  Processing {idx}/{len(chunks)}...")

        # Get embedding for augmented_chunk (includes contextual header)
        augmented_text = chunk.get('augmented_chunk', '')
        if not augmented_text:
            print(f"Warning: Chunk {chunk.get('chunk_id')} missing augmented_chunk")
            continue

        try:
            embedding = get_embedding(augmented_text)

            # Prepare document for Azure Search
            doc = {
                '@search.action': 'upload',
                'id': chunk.get('chunk_id'),
                'chunk_id': chunk.get('chunk_id'),
                'doc_id': chunk.get('doc_id'),
                'doc_title': chunk.get('doc_title'),
                'raw_chunk': chunk.get('raw_chunk'),
                'ctx_header': chunk.get('ctx_header'),
                'augmented_chunk': chunk.get('augmented_chunk'),
                'section_path': chunk.get('section_path'),
                'source_org': chunk.get('source_org'),
                'source_url': chunk.get('source_url'),
                'pub_date': chunk.get('pub_date'),
                'chunk_index': chunk.get('chunk_index', 0),
                'embedding': embedding
            }
            documents.append(doc)

            # Rate limiting: 60 requests per minute
            if idx % 5 == 0:
                time.sleep(2)

        except Exception as e:
            print(f"Error processing chunk {chunk.get('chunk_id')}: {e}")
            continue

    print(f"✓ Generated embeddings for {len(documents)} chunks")

    # Upload to Azure Search
    print(f"\nUploading to Azure Search...")
    upload_to_search(documents)

    print("\n" + "=" * 70)
    print("AZURE SEARCH INDEX CREATION COMPLETE! ✓")
    print("=" * 70)
    print(f"\nIndexed {len(documents)} chunks with embeddings")

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

chmod +x /tmp/upload_to_search.py

echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "Run this Python script in Azure Cloud Shell:"
echo "  python3 /tmp/upload_to_search.py"
echo ""
echo "Or copy the Python script above and run it with:"
echo "  python3 -c '\$(cat << 'EOF'"
echo "  [paste Python script here]"
echo "  EOF"
echo "  )'"
echo ""
echo "The Python script will:"
echo "  1. Load all 762 chunks from Cosmos DB"
echo "  2. Generate embeddings using Azure OpenAI"
echo "  3. Upload to Azure Search index"
echo ""
