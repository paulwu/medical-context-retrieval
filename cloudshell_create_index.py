#!/usr/bin/env python3
"""
Azure Search Index Creation for Cloud Shell
Uses only standard library + requests (pre-installed in Cloud Shell)

Upload this single file to Cloud Shell and run:
  python3 cloudshell_create_index.py
"""
import os
import sys
import json
import time
import requests
from typing import List, Dict, Any

# ============================================================================
# Configuration
#
# IMPORTANT: Do not hard-code secrets in this file.
# Export these variables in your Cloud Shell session instead.
# ============================================================================

def _require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise SystemExit(
            f"Missing required env var: {name}\n"
            "Set it in your shell session (e.g. `export NAME=...`) and rerun."
        )
    return value


CONFIG = {
    # Cosmos DB
    'COSMOS_ENDPOINT': _require_env('COSMOS_ENDPOINT'),
    'COSMOS_KEY': _require_env('COSMOS_KEY'),
    'COSMOS_DB_NAME': os.getenv('COSMOS_DB_NAME', 'medical-context-db'),
    'COSMOS_CONTAINER_CHUNKS': os.getenv('COSMOS_CONTAINER_CHUNKS', 'chunks'),

    # Azure Search
    'AZURE_SEARCH_ENDPOINT': _require_env('AZURE_SEARCH_ENDPOINT'),
    'AZURE_SEARCH_KEY': _require_env('AZURE_SEARCH_KEY'),
    'AZURE_SEARCH_INDEX_NAME': os.getenv('AZURE_SEARCH_INDEX_NAME', 'medical-context-index'),

    # Azure OpenAI
    'AZURE_OPENAI_ENDPOINT': _require_env('AZURE_OPENAI_ENDPOINT'),
    'AZURE_OPENAI_API_KEY': _require_env('AZURE_OPENAI_API_KEY'),
    'AOAI_EMBED_MODEL': os.getenv('AOAI_EMBED_MODEL', 'text-embedding-3-large'),
}

# ============================================================================
# Helper Functions
# ============================================================================

def load_chunks_from_cosmos() -> List[Dict[str, Any]]:
    """Load all chunks from Cosmos DB using REST API"""
    endpoint = CONFIG['COSMOS_ENDPOINT'].rstrip('/')
    key = CONFIG['COSMOS_KEY']
    db_name = CONFIG['COSMOS_DB_NAME']
    container_name = CONFIG['COSMOS_CONTAINER_CHUNKS']

    print(f"\n[Loading from Cosmos DB]")
    print(f"  Endpoint: {endpoint}")
    print(f"  Database: {db_name}")
    print(f"  Container: {container_name}")

    # Cosmos DB SQL API endpoint
    url = f"{endpoint}/dbs/{db_name}/colls/{container_name}/docs"

    headers = {
        'Authorization': key,
        'x-ms-version': '2018-12-31',
        'x-ms-documentdb-isquery': 'True',
        'Content-Type': 'application/query+json',
        'x-ms-max-item-count': '-1'  # Get all items
    }

    query_body = {
        'query': 'SELECT * FROM c',
        'parameters': []
    }

    try:
        response = requests.post(url, headers=headers, json=query_body, timeout=30)
        response.raise_for_status()

        data = response.json()
        chunks = data.get('Documents', [])

        print(f"  ✓ Loaded {len(chunks)} chunks")

        # Verify chunks have headers
        with_headers = sum(1 for c in chunks if c.get('ctx_header'))
        print(f"  ✓ {with_headers}/{len(chunks)} have contextual headers")

        return chunks

    except Exception as e:
        print(f"  ✗ Error loading from Cosmos DB: {e}")
        sys.exit(1)


def create_search_index():
    """Create Azure Search index with vector search support"""
    endpoint = CONFIG['AZURE_SEARCH_ENDPOINT'].rstrip('/')
    key = CONFIG['AZURE_SEARCH_KEY']
    index_name = CONFIG['AZURE_SEARCH_INDEX_NAME']

    print(f"\n[Creating Azure Search Index]")
    print(f"  Endpoint: {endpoint}")
    print(f"  Index: {index_name}")

    url = f"{endpoint}/indexes/{index_name}?api-version=2023-11-01"

    headers = {
        'api-key': key,
        'Content-Type': 'application/json'
    }

    index_schema = {
        'name': index_name,
        'fields': [
            {'name': 'id', 'type': 'Edm.String', 'key': True, 'searchable': False},
            {'name': 'chunk_id', 'type': 'Edm.String', 'searchable': False, 'filterable': True},
            {'name': 'doc_id', 'type': 'Edm.String', 'searchable': False, 'filterable': True},
            {'name': 'doc_title', 'type': 'Edm.String', 'searchable': True, 'filterable': True},
            {'name': 'raw_chunk', 'type': 'Edm.String', 'searchable': True},
            {'name': 'ctx_header', 'type': 'Edm.String', 'searchable': True},
            {'name': 'augmented_chunk', 'type': 'Edm.String', 'searchable': True},
            {'name': 'section_path', 'type': 'Edm.String', 'searchable': False, 'filterable': True},
            {'name': 'source_org', 'type': 'Edm.String', 'searchable': False, 'filterable': True},
            {'name': 'source_url', 'type': 'Edm.String', 'searchable': False},
            {'name': 'pub_date', 'type': 'Edm.String', 'searchable': False, 'filterable': True},
            {'name': 'chunk_index', 'type': 'Edm.Int32', 'searchable': False, 'filterable': True, 'sortable': True},
            {
                'name': 'embedding',
                'type': 'Collection(Edm.Single)',
                'searchable': True,
                'dimensions': 3072,
                'vectorSearchProfile': 'medical-context-vector-profile'
            }
        ],
        'vectorSearch': {
            'algorithms': [
                {
                    'name': 'medical-context-hnsw',
                    'kind': 'hnsw',
                    'hnswParameters': {
                        'm': 4,
                        'efConstruction': 400,
                        'efSearch': 500,
                        'metric': 'cosine'
                    }
                }
            ],
            'profiles': [
                {
                    'name': 'medical-context-vector-profile',
                    'algorithm': 'medical-context-hnsw'
                }
            ]
        },
        'semantic': {
            'configurations': [
                {
                    'name': 'medical-semantic-config',
                    'prioritizedFields': {
                        'titleField': {'fieldName': 'doc_title'},
                        'contentFields': [
                            {'fieldName': 'augmented_chunk'},
                            {'fieldName': 'ctx_header'}
                        ]
                    }
                }
            ]
        }
    }

    try:
        response = requests.put(url, headers=headers, json=index_schema, timeout=30)
        response.raise_for_status()
        print(f"  ✓ Index created/updated successfully")

    except Exception as e:
        print(f"  ✗ Error creating index: {e}")
        if hasattr(e, 'response') and e.response:
            print(f"  Response: {e.response.text}")
        sys.exit(1)


def get_embedding(text: str) -> List[float]:
    """Get embedding vector for text using Azure OpenAI"""
    endpoint = CONFIG['AZURE_OPENAI_ENDPOINT'].rstrip('/')
    key = CONFIG['AZURE_OPENAI_API_KEY']
    model = CONFIG['AOAI_EMBED_MODEL']

    url = f"{endpoint}/openai/deployments/{model}/embeddings?api-version=2023-05-15"

    headers = {
        'api-key': key,
        'Content-Type': 'application/json'
    }

    data = {'input': text}

    try:
        response = requests.post(url, headers=headers, json=data, timeout=30)
        response.raise_for_status()
        result = response.json()
        return result['data'][0]['embedding']

    except Exception as e:
        print(f"    ✗ Error getting embedding: {e}")
        raise


def upload_to_search(documents: List[Dict[str, Any]]):
    """Upload documents with embeddings to Azure Search"""
    endpoint = CONFIG['AZURE_SEARCH_ENDPOINT'].rstrip('/')
    key = CONFIG['AZURE_SEARCH_KEY']
    index_name = CONFIG['AZURE_SEARCH_INDEX_NAME']

    print(f"\n[Uploading to Azure Search]")

    url = f"{endpoint}/indexes/{index_name}/docs/index?api-version=2023-11-01"

    headers = {
        'api-key': key,
        'Content-Type': 'application/json'
    }

    # Upload in batches of 100
    batch_size = 100
    total_batches = (len(documents) + batch_size - 1) // batch_size

    for i in range(0, len(documents), batch_size):
        batch = documents[i:i+batch_size]
        batch_num = i // batch_size + 1

        data = {'value': batch}

        print(f"  [Batch {batch_num}/{total_batches}] Uploading {len(batch)} documents...")

        try:
            response = requests.post(url, headers=headers, json=data, timeout=60)
            response.raise_for_status()

            # Rate limiting
            if i + batch_size < len(documents):
                time.sleep(1)

        except Exception as e:
            print(f"    ✗ Error uploading batch: {e}")
            if hasattr(e, 'response') and e.response:
                print(f"    Response: {e.response.text}")
            sys.exit(1)

    print(f"  ✓ Uploaded {len(documents)} documents successfully")


def main():
    print("=" * 70)
    print("AZURE SEARCH INDEX CREATION (Cloud Shell)")
    print("=" * 70)

    # Step 1: Create index schema
    create_search_index()

    # Step 2: Load chunks from Cosmos DB
    chunks = load_chunks_from_cosmos()

    if not chunks:
        print("No chunks found in Cosmos DB")
        sys.exit(1)

    # Step 3: Generate embeddings and prepare documents
    print(f"\n[Generating Embeddings]")
    print(f"  Processing {len(chunks)} chunks...")
    print(f"  ⏳ Estimated time: ~5-10 minutes")

    documents = []
    errors = 0

    for idx, chunk in enumerate(chunks, 1):
        if idx % 50 == 0 or idx == 1:
            print(f"  [{idx}/{len(chunks)}] Processing...")

        augmented_text = chunk.get('augmented_chunk', '')

        if not augmented_text:
            print(f"    Warning: Chunk {chunk.get('chunk_id')} missing augmented_chunk")
            errors += 1
            continue

        try:
            # Get embedding
            embedding = get_embedding(augmented_text)

            # Prepare document
            doc = {
                '@search.action': 'upload',
                'id': chunk.get('chunk_id'),
                'chunk_id': chunk.get('chunk_id'),
                'doc_id': chunk.get('doc_id'),
                'doc_title': chunk.get('doc_title'),
                'raw_chunk': chunk.get('raw_chunk'),
                'ctx_header': chunk.get('ctx_header'),
                'augmented_chunk': chunk.get('augmented_chunk'),
                'section_path': chunk.get('section_path', ''),
                'source_org': chunk.get('source_org', ''),
                'source_url': chunk.get('source_url', ''),
                'pub_date': chunk.get('pub_date', ''),
                'chunk_index': chunk.get('chunk_index', 0),
                'embedding': embedding
            }

            documents.append(doc)

            # Rate limiting: ~60 requests per minute = 1 per second
            # Be conservative with 5 per batch then 2 second wait
            if idx % 5 == 0:
                time.sleep(2)

        except Exception as e:
            print(f"    Error processing chunk {chunk.get('chunk_id')}: {e}")
            errors += 1
            continue

    print(f"  ✓ Generated {len(documents)} embeddings")
    if errors:
        print(f"  ⚠ {errors} errors encountered")

    # Step 4: Upload to search
    upload_to_search(documents)

    # Summary
    print("\n" + "=" * 70)
    print("MIGRATION COMPLETE! ✓")
    print("=" * 70)
    print(f"\n📊 Summary:")
    print(f"  • Chunks indexed: {len(documents)}")
    print(f"  • Embedding dimensions: 3072")
    print(f"  • Index name: {CONFIG['AZURE_SEARCH_INDEX_NAME']}")
    print(f"\n🚀 Next: Test retrieval from your application")
    print("=" * 70)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
