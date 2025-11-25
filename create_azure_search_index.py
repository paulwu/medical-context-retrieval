#!/usr/bin/env python3
"""
Create Azure Search Index from Cosmos DB Data

This script:
1. Loads chunks from Cosmos DB (already uploaded with headers)
2. Generates embeddings for all chunks
3. Creates Azure Search index and uploads vectors

Can be run from WSL2 or Azure Cloud Shell if DNS issues occur.
"""
import os
import sys
from pathlib import Path

# Set Azure mode
os.environ['STORAGE_MODE'] = 'azure'

# Load environment variables
from dotenv import load_dotenv
env_path = Path(__file__).parent / '.env'
load_dotenv(env_path, override=True)

from rag import config, azure_cosmos, azure_search
from rag.embeddings import get_embeddings_batch
import numpy as np
import time

def create_search_index():
    print("=" * 70)
    print("AZURE SEARCH INDEX CREATION")
    print("=" * 70)

    print(f"\nAzure Search Endpoint: {config.AZURE_SEARCH_ENDPOINT}")
    print(f"Index Name: {config.AZURE_SEARCH_INDEX_NAME}")
    print(f"\nCosmos DB: {config.COSMOS_ENDPOINT}")

    # Step 1: Load chunks from Cosmos DB
    print("\n[Step 1/4] Loading chunks from Cosmos DB...")
    chunks = azure_cosmos.load_chunks()
    print(f"✓ Loaded {len(chunks)} chunks with contextual headers")

    if not chunks:
        print("❌ No chunks found in Cosmos DB. Run migrate_to_cosmos.py first.")
        sys.exit(1)

    # Verify chunks have headers
    chunks_with_headers = sum(1 for c in chunks if c.ctx_header)
    print(f"  • {chunks_with_headers}/{len(chunks)} chunks have contextual headers")

    # Step 2: Create Azure Search index schema
    print("\n[Step 2/4] Creating Azure Search index...")
    try:
        azure_search.create_search_index(embedding_dimensions=3072)
        print(f"✓ Index '{config.AZURE_SEARCH_INDEX_NAME}' created/verified")
    except Exception as e:
        print(f"❌ Failed to create index: {e}")
        print("\nTroubleshooting:")
        print("  • If DNS error: Try running from Azure Cloud Shell")
        print("  • If auth error: Verify AZURE_SEARCH_KEY is the admin key")
        print("  • If quota error: Check Azure Search service tier")
        sys.exit(1)

    # Step 3: Generate embeddings
    print("\n[Step 3/4] Generating embeddings for all chunks...")
    print(f"  Processing {len(chunks)} chunks in batches of {config.EMBED_BATCH_SIZE}")
    print(f"  Delay between batches: {config.EMBED_DELAY_SECONDS}s")
    print("  ⏳ This will take approximately 5-10 minutes...")

    # Use augmented_chunk (includes contextual header)
    texts = [chunk.augmented_chunk for chunk in chunks]

    # Generate embeddings in batches
    all_embeddings = []
    total_batches = (len(texts) + config.EMBED_BATCH_SIZE - 1) // config.EMBED_BATCH_SIZE

    for i in range(0, len(texts), config.EMBED_BATCH_SIZE):
        batch_texts = texts[i:i + config.EMBED_BATCH_SIZE]
        batch_num = i // config.EMBED_BATCH_SIZE + 1

        print(f"  [Batch {batch_num}/{total_batches}] Processing {len(batch_texts)} chunks...")

        try:
            batch_embeddings = get_embeddings_batch(batch_texts)
            all_embeddings.extend(batch_embeddings)

            # Rate limiting delay
            if i + config.EMBED_BATCH_SIZE < len(texts):
                time.sleep(config.EMBED_DELAY_SECONDS)

        except Exception as e:
            print(f"❌ Failed to generate embeddings for batch {batch_num}: {e}")
            sys.exit(1)

    embeddings = np.array(all_embeddings, dtype=np.float32)
    print(f"✓ Generated {len(embeddings)} embeddings ({embeddings.shape[1]} dimensions)")

    # Step 4: Upload to Azure Search
    print("\n[Step 4/4] Uploading chunks with embeddings to Azure Search...")
    try:
        azure_search.upload_chunks(chunks, embeddings, batch_size=100)
        print(f"✓ Uploaded {len(chunks)} chunks to Azure Search")
    except Exception as e:
        print(f"❌ Failed to upload to Azure Search: {e}")
        sys.exit(1)

    # Verify
    print("\n[Verification] Checking Azure Search index...")
    try:
        doc_count = azure_search.get_document_count()
        print(f"✓ Azure Search index contains {doc_count} documents")
    except Exception as e:
        print(f"⚠️  Could not verify document count: {e}")

    # Final summary
    print("\n" + "=" * 70)
    print("AZURE SEARCH INDEX CREATION COMPLETE! ✓")
    print("=" * 70)
    print(f"\n📊 Summary:")
    print(f"  • Chunks indexed: {len(chunks)}")
    print(f"  • Chunks with headers: {chunks_with_headers}")
    print(f"  • Embedding dimensions: {embeddings.shape[1]}")
    print(f"  • Azure Search index: {config.AZURE_SEARCH_INDEX_NAME}")
    print(f"\n🚀 Next steps:")
    print(f"  1. Test retrieval: python3 test_azure_retrieval.py")
    print(f"  2. Update notebooks to use Azure mode")
    print("=" * 70)

def main():
    try:
        create_search_index()
    except KeyboardInterrupt:
        print("\n\n⚠️  Index creation interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Index creation failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
