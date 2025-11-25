#!/usr/bin/env python3
"""
Azure Migration Script: Build cloud-native index with contextual headers

This script:
1. Loads documents from data_pilot/
2. Generates contextual headers (includes chunking)
3. Uploads to Azure Cosmos DB
4. Creates Azure AI Search index with embeddings
"""
import os
import sys
import asyncio

# Set Azure mode
os.environ['STORAGE_MODE'] = 'azure'

from rag import config, ingestion, cache, azure_cosmos, azure_search
from rag.headers import generate_headers, azure_chat_completion

async def migrate():
    print("=" * 70)
    print("AZURE MIGRATION: Building Cloud-Native Index with Headers")
    print("=" * 70)

    # Step 1: Load documents from source
    print("\n[Step 1/5] Loading documents from data_pilot directory...")
    docs = ingestion.load_json_documents(config.DATA_DIR)
    print(f"✓ Loaded {len(docs)} documents")
    for doc in docs[:3]:
        print(f"  • {doc.title[:60]}...")

    # Step 2: Generate contextual headers (includes chunking)
    print("\n[Step 2/5] Generating contextual headers...")
    print("  ⏳ This uses Azure OpenAI to create context for each chunk...")
    print(f"  Processing with rate limits: {config.REQUESTS_PER_MIN} req/min")

    chunks = await generate_headers(
        documents=docs,
        llm=azure_chat_completion,
        use_tqdm=False  # Use manual progress reporting
    )

    print(f"✓ Generated {len(chunks)} chunks with contextual headers")
    if chunks:
        sample = chunks[0]
        print(f"  Sample header: {sample.ctx_header[:80]}...")
        print(f"  Sample chunk: {sample.raw_chunk[:80]}...")

    # Step 3: Save to Cosmos DB
    print("\n[Step 3/5] Uploading to Azure Cosmos DB...")
    azure_cosmos.save_documents(docs)
    print(f"✓ Uploaded {len(docs)} documents to Cosmos DB")

    azure_cosmos.save_chunks(chunks)
    print(f"✓ Uploaded {len(chunks)} chunks to Cosmos DB")

    # Verify
    stats = azure_cosmos.get_stats()
    print(f"  Database stats: {stats['document_count']} docs, {stats['chunk_count']} chunks")

    # Step 4: Create Azure Search index with embeddings
    print("\n[Step 4/5] Creating Azure AI Search index...")
    print("  ⏳ Generating embeddings and uploading to Azure Search...")
    print(f"  Processing {len(chunks)} chunks in batches of {config.EMBED_BATCH_SIZE}")
    print(f"  Delay between batches: {config.EMBED_DELAY_SECONDS}s")

    # Prepare texts and metadata
    # Use augmented_chunk (which includes the contextual header)
    texts = [chunk.augmented_chunk for chunk in chunks]
    metadata = [
        {
            "chunk_id": chunk.chunk_id,
            "doc_id": chunk.doc_id,
            "doc_title": chunk.doc_title,
            "raw_chunk": chunk.raw_chunk,
            "ctx_header": chunk.ctx_header,
            "augmented_chunk": chunk.augmented_chunk,
            "section_path": chunk.section_path,
            "source_org": chunk.source_org,
            "source_url": chunk.source_url,
            "pub_date": chunk.pub_date,
            "chunk_index": chunk.chunk_index,
        }
        for chunk in chunks
    ]

    # Build index (this generates embeddings and uploads to Azure Search)
    index, meta, embeddings = cache.build_or_load_index(
        texts=texts,
        metadata=metadata,
        chunks=chunks,
        force=True  # Force rebuild for initial migration
    )

    print(f"✓ Created Azure Search index with {len(chunks)} vectors")

    # Step 5: Verify Azure Search
    print("\n[Step 5/5] Verifying Azure AI Search index...")
    doc_count = azure_search.get_document_count()
    print(f"✓ Azure Search index contains {doc_count} documents")

    # Final summary
    print("\n" + "=" * 70)
    print("MIGRATION COMPLETE! ✓")
    print("=" * 70)
    print(f"\n📊 Summary:")
    print(f"  • Documents in Cosmos DB: {stats['document_count']}")
    print(f"  • Chunks in Cosmos DB: {stats['chunk_count']}")
    print(f"  • Chunks with headers: {len(chunks)}")
    print(f"  • Vectors in Azure Search: {doc_count}")
    print(f"  • Embedding dimensions: {embeddings.shape[1]}")
    print(f"\n💡 Key Features:")
    print(f"  • Contextual headers generated for all chunks")
    print(f"  • Headers improve retrieval accuracy")
    print(f"  • Data stored in Azure Cosmos DB")
    print(f"  • Vector search via Azure AI Search")
    print(f"\n🚀 Next steps:")
    print(f"  1. Test retrieval: python3 test_azure_retrieval.py")
    print(f"  2. Update .env: Set STORAGE_MODE=azure")
    print(f"  3. Update notebooks to use Azure mode")
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
