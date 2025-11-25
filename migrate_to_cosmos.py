#!/usr/bin/env python3
"""
Fresh migration to NEW Cosmos DB only (skip Azure Search for now)

This script:
1. Clears any cached environment variables
2. Loads fresh from .env
3. Uploads to the CORRECT Cosmos DB (medctx-demo-cosmos)
4. Skips Azure Search (will do that separately when DNS works)
"""
import os
import sys

# CRITICAL: Clear any existing Cosmos DB environment variables before loading .env
for key in list(os.environ.keys()):
    if 'COSMOS' in key:
        del os.environ[key]

# Now load fresh from .env
from pathlib import Path
from dotenv import load_dotenv

env_path = Path(__file__).parent / '.env'
load_dotenv(env_path, override=True)  # override=True forces reload

# Verify we're using the correct Cosmos DB
cosmos_endpoint = os.getenv('COSMOS_ENDPOINT')
print(f"Using Cosmos DB: {cosmos_endpoint}")
assert 'medctx-demo-cosmos' in cosmos_endpoint, f"Wrong Cosmos DB! Got: {cosmos_endpoint}"

# Set Azure mode
os.environ['STORAGE_MODE'] = 'azure'

import asyncio
from rag import ingestion, config, azure_cosmos
from rag.headers import generate_headers, azure_chat_completion

async def migrate():
    print("=" * 70)
    print("COSMOS DB MIGRATION: Fresh Upload to medctx-demo-cosmos")
    print("=" * 70)

    print(f"\nTarget Cosmos DB: {config.COSMOS_ENDPOINT}")
    print(f"Database: {config.COSMOS_DB_NAME}")
    print(f"Containers: {config.COSMOS_CONTAINER_DOCUMENTS}, {config.COSMOS_CONTAINER_CHUNKS}")

    # Step 1: Initialize Cosmos DB
    print("\n[Step 1/5] Initializing Cosmos DB...")
    azure_cosmos.init_cosmos_db()
    print("✓ Cosmos DB initialized")

    # Step 2: Load documents
    print("\n[Step 2/5] Loading documents from data_pilot...")
    docs = ingestion.load_json_documents(config.DATA_DIR)
    print(f"✓ Loaded {len(docs)} documents")

    # Step 3: Generate headers
    print("\n[Step 3/5] Generating contextual headers...")
    print("  ⏳ This uses Azure OpenAI (will take ~10 minutes)...")

    chunks = await generate_headers(
        documents=docs,
        llm=azure_chat_completion,
        use_tqdm=False
    )

    print(f"✓ Generated {len(chunks)} chunks with headers")

    # Step 4: Upload to Cosmos DB
    print("\n[Step 4/5] Uploading to Cosmos DB...")
    azure_cosmos.save_documents(docs)
    print(f"✓ Uploaded {len(docs)} documents")

    azure_cosmos.save_chunks(chunks)
    print(f"✓ Uploaded {len(chunks)} chunks")

    # Step 5: Verify
    print("\n[Step 5/5] Verifying upload...")
    stats = azure_cosmos.get_stats()
    print(f"✓ Database: {stats['database']}")
    print(f"✓ Documents container: {stats['documents_container']} ({stats['document_count']} docs)")
    print(f"✓ Chunks container: {stats['chunks_container']} ({stats['chunk_count']} chunks)")

    print("\n" + "=" * 70)
    print("COSMOS DB MIGRATION COMPLETE! ✓")
    print("=" * 70)
    print(f"\n📊 Summary:")
    print(f"  • Cosmos DB: medctx-demo-cosmos")
    print(f"  • Database: {stats['database']}")
    print(f"  • Documents: {stats['document_count']}")
    print(f"  • Chunks with headers: {stats['chunk_count']}")
    print(f"\n⏳ Next: Fix Azure Search DNS, then create search index")
    print("=" * 70)

def main():
    try:
        asyncio.run(migrate())
    except KeyboardInterrupt:
        print("\n\n⚠️  Migration interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Migration failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
