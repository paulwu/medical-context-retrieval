"""Populate Azure AI Search with chunks and embeddings from Cosmos DB.

This is the fast, manual approach:
1. Create simple index (no vectorizer)
2. Load chunks from Cosmos DB
3. Generate embeddings
4. Upload to Azure Search
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
os.environ['STORAGE_MODE'] = 'azure'

from rag import config, azure_cosmos, azure_search
from rag.embeddings import get_embeddings_batch
import numpy as np
import time

print("=" * 70)
print("Populate Azure AI Search from Cosmos DB")
print("=" * 70)

# Step 1: Create simple index
print("\n[1/4] Creating Azure Search index...")
azure_search.create_search_index(embedding_dimensions=3072)
print("      Index created")

# Step 2: Load chunks from Cosmos DB
print("\n[2/4] Loading chunks from Cosmos DB...")
chunks = azure_cosmos.load_chunks()
print(f"      Loaded {len(chunks)} chunks")

if not chunks:
    print("[ERROR] No chunks found in Cosmos DB")
    sys.exit(1)

# Step 3: Generate embeddings
print(f"\n[3/4] Generating embeddings...")
print(f"      Batch size: {config.EMBED_BATCH_SIZE}, Delay: {config.EMBED_DELAY_SECONDS}s")

texts = [c.augmented_chunk for c in chunks]
embeddings_list = []
batch_size = config.EMBED_BATCH_SIZE
total_batches = (len(texts) + batch_size - 1) // batch_size

for i in range(0, len(texts), batch_size):
    batch = texts[i:i + batch_size]
    batch_num = i // batch_size + 1
    
    print(f"      Batch {batch_num}/{total_batches}...", end=" ", flush=True)
    batch_emb = get_embeddings_batch(batch)
    embeddings_list.extend(batch_emb)
    print("done")
    
    if batch_num < total_batches:
        time.sleep(config.EMBED_DELAY_SECONDS)

embeddings = np.asarray(embeddings_list, dtype=np.float32)
print(f"      Generated: {embeddings.shape}")

# Step 4: Upload to Azure Search
print(f"\n[4/4] Uploading to Azure AI Search...")
azure_search.upload_chunks(chunks, embeddings, batch_size=100)

# Verify
count = azure_search.get_document_count()
print(f"\n{'=' * 70}")
print(f"SUCCESS! {count} documents in Azure Search")
print(f"{'=' * 70}")
