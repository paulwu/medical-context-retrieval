"""Caching utilities for documents, chunks, embeddings, and vector index.

Design goals:
- Idempotent: safe to call repeatedly without corrupting state.
- Atomic writes: write to temp then rename to avoid partial files.
- Supports both local (FAISS + JSON) and Azure (Azure Search + Cosmos DB) storage.
- Layered: documents -> chunks -> embeddings -> index.

Storage modes (controlled by STORAGE_MODE config):
- 'local': Use FAISS + JSON files (default, backward compatible)
- 'azure': Use Azure AI Search + Cosmos DB (cloud-native)

Public functions:
- save_documents(docs)
- load_documents()
- save_chunks(chunks)
- load_chunks()
- save_embeddings(emb_matrix)
- load_embeddings()
- save_faiss_index(index) [local mode only]
- load_faiss_index() [local mode only]
- build_or_load_index(texts, embed_fn, force=False)

The build_or_load_index helper derives embeddings (if needed) and returns (index, metadata, embeddings).
"""
from __future__ import annotations
from typing import List, Sequence, Dict, Any, Tuple, Callable, Optional, Union
import json, os, tempfile
from pathlib import Path
import numpy as np

from . import config
from .models import Document, Chunk
from .embeddings import get_embeddings_batch

# Import FAISS conditionally (only needed for local mode)
try:
    import faiss  # type: ignore
    from .index import build_faiss_index
    FAISS_AVAILABLE = True
except ImportError:
    FAISS_AVAILABLE = False
    faiss = None

# Import Azure modules conditionally (only needed for Azure mode)
try:
    from . import azure_search, azure_cosmos
    AZURE_AVAILABLE = True
except ImportError:
    AZURE_AVAILABLE = False

DOCS_PATH = config.CACHE_DIR / "documents.json"
CHUNKS_PATH = config.CACHE_DIR / "chunks.json"
EMB_PATH = config.CACHE_DIR / "embeddings.npy"
INDEX_PATH = config.CACHE_DIR / "faiss.index"
META_PATH = config.CACHE_DIR / "metadata.json"

# ----------------------- generic helpers -----------------------

def _atomic_write(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as tmp:
        tmp.write(data)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)

# ----------------------- documents -----------------------------

def save_documents(docs: Sequence[Document]):
    """Save documents to local JSON or Azure Cosmos DB based on STORAGE_MODE."""
    if config.STORAGE_MODE == "azure":
        if not AZURE_AVAILABLE:
            raise RuntimeError("Azure modules not available. Install azure-cosmos.")
        azure_cosmos.save_documents(list(docs))
    else:
        # Local mode (default)
        payload = [doc.__dict__ for doc in docs]
        _atomic_write(DOCS_PATH, json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8"))


def load_documents() -> List[Document]:
    """Load documents from local JSON or Azure Cosmos DB based on STORAGE_MODE."""
    if config.STORAGE_MODE == "azure":
        if not AZURE_AVAILABLE:
            raise RuntimeError("Azure modules not available. Install azure-cosmos.")
        return azure_cosmos.load_documents()
    else:
        # Local mode (default)
        if not DOCS_PATH.exists():
            return []
        data = json.loads(DOCS_PATH.read_text("utf-8"))
        return [Document(**d) for d in data]

# ----------------------- chunks --------------------------------

def save_chunks(chunks: Sequence[Chunk]):
    """Save chunks to local JSON or Azure Cosmos DB based on STORAGE_MODE."""
    if config.STORAGE_MODE == "azure":
        if not AZURE_AVAILABLE:
            raise RuntimeError("Azure modules not available. Install azure-cosmos.")
        azure_cosmos.save_chunks(list(chunks))
    else:
        # Local mode (default)
        payload = [c.__dict__ for c in chunks]
        _atomic_write(CHUNKS_PATH, json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8"))


def load_chunks() -> List[Chunk]:
    """Load chunks from local JSON or Azure Cosmos DB based on STORAGE_MODE."""
    if config.STORAGE_MODE == "azure":
        if not AZURE_AVAILABLE:
            raise RuntimeError("Azure modules not available. Install azure-cosmos.")
        return azure_cosmos.load_chunks()
    else:
        # Local mode (default)
        if not CHUNKS_PATH.exists():
            return []
        data = json.loads(CHUNKS_PATH.read_text("utf-8"))
        return [Chunk(**c) for c in data]

# ----------------------- embeddings ----------------------------

def save_embeddings(embeddings: np.ndarray):
    embeddings = np.asarray(embeddings, dtype=np.float32)
    np.save(EMB_PATH, embeddings)


def load_embeddings() -> Optional[np.ndarray]:
    if not EMB_PATH.exists():
        return None
    return np.load(EMB_PATH)

# ----------------------- metadata & index ----------------------

def save_metadata(meta: Sequence[Dict[str, Any]]):
    _atomic_write(META_PATH, json.dumps(list(meta), ensure_ascii=False, indent=2).encode("utf-8"))


def load_metadata() -> List[Dict[str, Any]]:
    if not META_PATH.exists():
        return []
    return json.loads(META_PATH.read_text("utf-8"))


def save_faiss_index(index):
    """Save FAISS index (local mode only)."""
    if not FAISS_AVAILABLE:
        raise RuntimeError("FAISS not available. Install faiss-cpu.")
    faiss.write_index(index, str(INDEX_PATH))


def load_faiss_index() -> Optional[Any]:
    """Load FAISS index (local mode only)."""
    if not FAISS_AVAILABLE:
        raise RuntimeError("FAISS not available. Install faiss-cpu.")
    if not INDEX_PATH.exists():
        return None
    return faiss.read_index(str(INDEX_PATH))

# ----------------------- orchestration -------------------------

def build_or_load_index(
    texts: Sequence[str],
    metadata: Sequence[Dict[str, Any]],
    chunks: Optional[List[Chunk]] = None,
    embed_fn: Optional[Callable[[List[str]], List[List[float]]]] = None,
    force: bool = False,
    index_type: str = "auto",
) -> Tuple[Optional[Any], List[Dict[str, Any]], np.ndarray]:
    """Load cached index+embeddings or build from provided texts.

    Supports both local (FAISS) and Azure (Azure AI Search) modes.

    Parameters
    ----------
    texts : list of str
        The (augmented) chunk texts to embed.
    metadata : list of dict
        Parallel metadata aligned to texts.
    chunks : list of Chunk, optional
        Chunk objects (required for Azure mode).
    embed_fn : callable
        Embedding function (defaults to get_embeddings_batch).
    force : bool
        If True, rebuild even if cache exists.
    index_type : str
        Index strategy (only used in local/FAISS mode).

    Returns
    -------
    tuple
        (index, metadata, embeddings) where index is either faiss.Index or None (for Azure mode)
    """
    embed_fn = embed_fn or get_embeddings_batch

    if config.STORAGE_MODE == "azure":
        return _build_or_load_azure_index(texts, metadata, chunks, embed_fn, force)
    else:
        return _build_or_load_local_index(texts, metadata, embed_fn, force, index_type)


def _build_or_load_local_index(
    texts: Sequence[str],
    metadata: Sequence[Dict[str, Any]],
    embed_fn: Callable[[List[str]], List[List[float]]],
    force: bool,
    index_type: str,
) -> Tuple[Any, List[Dict[str, Any]], np.ndarray]:
    """Build or load index using local FAISS storage."""
    if not FAISS_AVAILABLE:
        raise RuntimeError("FAISS not available. Install faiss-cpu or set STORAGE_MODE=azure.")

    cached_index = load_faiss_index()
    cached_emb = load_embeddings()
    cached_meta = load_metadata()

    if not force and cached_index and cached_emb is not None and cached_meta and len(cached_meta) == len(texts):
        # Assume cache is valid if counts match
        print(f"[cache] Using cached index with {len(cached_meta)} vectors")
        return cached_index, cached_meta, cached_emb

    # Build fresh with batching and delays to avoid rate limits
    batch_size = config.EMBED_BATCH_SIZE
    batch_delay = config.EMBED_DELAY_SECONDS
    embeddings_list = []

    print(f"[embeddings] Processing {len(texts)} texts in batches of {batch_size} (delay: {batch_delay}s)")
    for i in range(0, len(texts), batch_size):
        batch = list(texts[i:i + batch_size])
        batch_embeddings = embed_fn(batch)
        if not batch_embeddings:
            raise RuntimeError(f"Failed to generate embeddings for batch {i//batch_size + 1}")
        embeddings_list.extend(batch_embeddings)
        batch_num = i//batch_size + 1
        total_batches = (len(texts) + batch_size - 1)//batch_size
        print(f"[embeddings] Completed batch {batch_num}/{total_batches}")

        # Add delay between batches (except for last batch)
        if batch_num < total_batches:
            import time
            time.sleep(batch_delay)

    if not embeddings_list:
        raise RuntimeError("Failed to generate embeddings")
    emb_matrix = np.asarray(embeddings_list, dtype=np.float32)
    index = build_faiss_index(embeddings_list, index_type=index_type)

    # Persist
    save_embeddings(emb_matrix)
    save_faiss_index(index)
    save_metadata(metadata)

    return index, list(metadata), emb_matrix


def _build_or_load_azure_index(
    texts: Sequence[str],
    metadata: Sequence[Dict[str, Any]],
    chunks: Optional[List[Chunk]],
    embed_fn: Callable[[List[str]], List[List[float]]],
    force: bool,
) -> Tuple[None, List[Dict[str, Any]], np.ndarray]:
    """Build or load index using Azure AI Search."""
    if not AZURE_AVAILABLE:
        raise RuntimeError("Azure modules not available. Install azure-search-documents and azure-cosmos.")

    if not chunks:
        raise ValueError("chunks parameter is required for Azure mode")

    # Check if index already exists
    try:
        doc_count = azure_search.get_document_count()
        if not force and doc_count == len(texts):
            print(f"[cache] Azure Search index exists with {doc_count} documents")
            # Still need to load/generate embeddings for compatibility
            cached_emb = load_embeddings()
            if cached_emb is not None and len(cached_emb) == len(texts):
                return None, list(metadata), cached_emb
    except Exception as e:
        print(f"[cache] Azure Search index doesn't exist or error checking: {e}")

    # Create the index schema
    print("[azure] Creating Azure AI Search index...")
    azure_search.create_search_index()

    # Generate embeddings with batching
    batch_size = config.EMBED_BATCH_SIZE
    batch_delay = config.EMBED_DELAY_SECONDS
    embeddings_list = []

    print(f"[embeddings] Processing {len(texts)} texts in batches of {batch_size} (delay: {batch_delay}s)")
    for i in range(0, len(texts), batch_size):
        batch = list(texts[i:i + batch_size])
        batch_embeddings = embed_fn(batch)
        if not batch_embeddings:
            raise RuntimeError(f"Failed to generate embeddings for batch {i//batch_size + 1}")
        embeddings_list.extend(batch_embeddings)
        batch_num = i//batch_size + 1
        total_batches = (len(texts) + batch_size - 1)//batch_size
        print(f"[embeddings] Completed batch {batch_num}/{total_batches}")

        # Add delay between batches (except for last batch)
        if batch_num < total_batches:
            import time
            time.sleep(batch_delay)

    if not embeddings_list:
        raise RuntimeError("Failed to generate embeddings")

    emb_matrix = np.asarray(embeddings_list, dtype=np.float32)

    # Upload chunks with embeddings to Azure Search
    print(f"[azure] Uploading {len(chunks)} chunks to Azure AI Search...")
    azure_search.upload_chunks(chunks, emb_matrix)

    # Save embeddings locally for backup/compatibility
    save_embeddings(emb_matrix)
    save_metadata(metadata)

    print("[azure] Azure AI Search index built successfully")
    return None, list(metadata), emb_matrix

__all__ = [
    "save_documents",
    "load_documents",
    "save_chunks",
    "load_chunks",
    "save_embeddings",
    "load_embeddings",
    "save_faiss_index",
    "load_faiss_index",
    "save_metadata",
    "load_metadata",
    "build_or_load_index",
]
