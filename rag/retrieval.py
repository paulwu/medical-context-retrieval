"""Unified retrieval abstraction supporting both FAISS and Azure AI Search."""
from __future__ import annotations
from typing import List, Dict, Any, Sequence, Optional
import numpy as np

from .embeddings import get_embeddings_batch
from . import config

# Import FAISS conditionally (only needed for local mode)
try:
    import faiss  # type: ignore
    FAISS_AVAILABLE = True
except ImportError:
    FAISS_AVAILABLE = False
    faiss = None

# Import Azure Search conditionally (only needed for Azure mode)
try:
    from . import azure_search
    AZURE_AVAILABLE = True
except ImportError:
    AZURE_AVAILABLE = False


class EmbeddingRetriever:
    """Embedding-based retriever supporting both FAISS and Azure AI Search.

    Parameters
    ----------
    index : faiss.Index | None
        FAISS index (for local mode) or None (for Azure mode).
        Vectors assumed already normalized for IP similarity in FAISS mode.
    metadata : Sequence[Dict[str, Any]]
        Parallel metadata list aligned with index order (local mode only).
    embed_fn : callable | None
        Function accepting List[str] -> List[List[float]]. Defaults to
        `rag.embeddings.get_embeddings_batch`. Allows injection of a fake
        embedding function for offline tests.
    use_azure : bool | None
        If True, use Azure AI Search. If False, use FAISS. If None, auto-detect
        based on config.STORAGE_MODE.
    """

    def __init__(
        self,
        index: Optional[Any] = None,
        metadata: Optional[Sequence[Dict[str, Any]]] = None,
        embed_fn=None,
        use_azure: Optional[bool] = None
    ):
        # Auto-detect mode if not specified
        if use_azure is None:
            use_azure = config.STORAGE_MODE == "azure"

        self.use_azure = use_azure
        self._embed_fn = embed_fn or get_embeddings_batch

        if self.use_azure:
            if not AZURE_AVAILABLE:
                raise RuntimeError("Azure modules not available. Install azure-search-documents.")
            # Azure mode: index is not used, metadata comes from Azure Search
            self.index = None
            self.metadata = []
        else:
            if not FAISS_AVAILABLE:
                raise RuntimeError("FAISS not available. Install faiss-cpu.")
            if index is None:
                raise ValueError("index parameter is required for local/FAISS mode")
            # FAISS mode
            self.index = index
            self.metadata = list(metadata) if metadata else []

    def embed_query(self, query: str) -> np.ndarray:
        """Generate embedding for a query string."""
        emb = self._embed_fn([query])
        if not emb:
            raise RuntimeError("Failed to embed query (empty embedding list)")
        vec = np.array([emb[0]], dtype=np.float32)

        # Normalize for FAISS (Azure Search handles normalization internally)
        if not self.use_azure and FAISS_AVAILABLE:
            faiss.normalize_L2(vec)

        return vec

    def search(self, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """Search for similar documents using vector similarity.

        Parameters
        ----------
        query : str
            Query text to search for
        top_k : int
            Number of top results to return

        Returns
        -------
        list of dict
            Search results with rank, similarity_score, and metadata
        """
        if self.use_azure:
            return self._search_azure(query, top_k)
        else:
            return self._search_faiss(query, top_k)

    def _search_faiss(self, query: str, top_k: int) -> List[Dict[str, Any]]:
        """Search using FAISS index (local mode)."""
        vec = self.embed_query(query)
        scores, indices = self.index.search(vec, top_k)
        out: List[Dict[str, Any]] = []

        for rank, (score, idx) in enumerate(zip(scores[0], indices[0]), 1):
            if idx < 0:
                break
            meta = self.metadata[idx] if idx < len(self.metadata) else {}
            out.append({
                "rank": rank,
                "similarity_score": float(score),
                **meta
            })
        return out

    def _search_azure(self, query: str, top_k: int) -> List[Dict[str, Any]]:
        """Search using Azure AI Search (cloud mode)."""
        # Use text search which lets Azure auto-vectorize the query
        results = azure_search.search_text(query, top_k=top_k)

        # Convert to the expected format
        out: List[Dict[str, Any]] = []
        for result in results:
            out.append({
                "rank": result.rank,
                "similarity_score": result.similarity,
                **result.metadata
            })
        return out


__all__ = ["EmbeddingRetriever"]
