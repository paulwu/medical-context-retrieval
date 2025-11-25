"""Azure AI Search integration for vector search (replaces FAISS).

This module provides functions to:
1. Create and configure Azure AI Search index with vector search
2. Upload document chunks with embeddings to the index
3. Perform vector similarity search
"""
from __future__ import annotations
import logging
from typing import List, Dict, Any, Optional
import numpy as np

from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex,
    SearchField,
    SearchFieldDataType,
    VectorSearch,
    HnswAlgorithmConfiguration,
    VectorSearchProfile,
    SemanticConfiguration,
    SemanticPrioritizedFields,
    SemanticField,
    SemanticSearch,
)

from . import config
from .models import Chunk, RetrievalResult

logger = logging.getLogger(__name__)


def _get_search_client() -> SearchClient:
    """Get Azure Search client for querying."""
    if not config.AZURE_SEARCH_ENDPOINT or not config.AZURE_SEARCH_KEY:
        raise RuntimeError(
            "Azure Search not configured. Set AZURE_SEARCH_ENDPOINT and AZURE_SEARCH_KEY"
        )

    credential = AzureKeyCredential(config.AZURE_SEARCH_KEY)
    return SearchClient(
        endpoint=config.AZURE_SEARCH_ENDPOINT,
        index_name=config.AZURE_SEARCH_INDEX_NAME,
        credential=credential
    )


def _get_index_client() -> SearchIndexClient:
    """Get Azure Search index client for management operations."""
    if not config.AZURE_SEARCH_ENDPOINT or not config.AZURE_SEARCH_KEY:
        raise RuntimeError(
            "Azure Search not configured. Set AZURE_SEARCH_ENDPOINT and AZURE_SEARCH_KEY"
        )

    credential = AzureKeyCredential(config.AZURE_SEARCH_KEY)
    return SearchIndexClient(
        endpoint=config.AZURE_SEARCH_ENDPOINT,
        credential=credential
    )


def create_search_index(embedding_dimensions: int = 3072) -> None:
    """Create or update Azure AI Search index with vector search capabilities.

    Args:
        embedding_dimensions: Dimension of embedding vectors (default: 3072 for text-embedding-3-large)
    """
    logger.info(f"Creating Azure AI Search index: {config.AZURE_SEARCH_INDEX_NAME}")

    # Define the fields for the index
    fields = [
        SearchField(
            name="chunk_id",
            type=SearchFieldDataType.String,
            key=True,
            sortable=True,
            filterable=True,
        ),
        SearchField(
            name="doc_id",
            type=SearchFieldDataType.String,
            filterable=True,
            sortable=True,
        ),
        SearchField(
            name="doc_title",
            type=SearchFieldDataType.String,
            searchable=True,
            filterable=True,
        ),
        SearchField(
            name="raw_chunk",
            type=SearchFieldDataType.String,
            searchable=True,
        ),
        SearchField(
            name="ctx_header",
            type=SearchFieldDataType.String,
            searchable=True,
        ),
        SearchField(
            name="augmented_chunk",
            type=SearchFieldDataType.String,
            searchable=True,
        ),
        SearchField(
            name="section_path",
            type=SearchFieldDataType.String,
            searchable=True,
            filterable=True,
        ),
        SearchField(
            name="source_org",
            type=SearchFieldDataType.String,
            filterable=True,
        ),
        SearchField(
            name="source_url",
            type=SearchFieldDataType.String,
            filterable=True,
        ),
        SearchField(
            name="pub_date",
            type=SearchFieldDataType.String,
            filterable=True,
            sortable=True,
        ),
        SearchField(
            name="chunk_index",
            type=SearchFieldDataType.Int32,
            filterable=True,
            sortable=True,
        ),
        # Vector field for embeddings
        SearchField(
            name="embedding",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=embedding_dimensions,
            vector_search_profile_name="medical-context-vector-profile",
        ),
    ]

    # Configure vector search with HNSW algorithm (similar to FAISS)
    vector_search = VectorSearch(
        algorithms=[
            HnswAlgorithmConfiguration(
                name="medical-context-hnsw",
                parameters={
                    "m": 4,  # Number of bi-directional links (similar to FAISS IVF)
                    "efConstruction": 400,  # Size of dynamic candidate list for construction
                    "efSearch": 500,  # Size of dynamic candidate list for search
                    "metric": "cosine",  # Use cosine similarity (similar to normalized L2)
                }
            )
        ],
        profiles=[
            VectorSearchProfile(
                name="medical-context-vector-profile",
                algorithm_configuration_name="medical-context-hnsw",
            )
        ]
    )

    # Configure semantic search for better ranking
    semantic_config = SemanticConfiguration(
        name="medical-context-semantic",
        prioritized_fields=SemanticPrioritizedFields(
            title_field=SemanticField(field_name="doc_title"),
            content_fields=[
                SemanticField(field_name="augmented_chunk"),
                SemanticField(field_name="ctx_header"),
                SemanticField(field_name="raw_chunk"),
            ]
        )
    )

    semantic_search = SemanticSearch(configurations=[semantic_config])

    # Create the index
    index = SearchIndex(
        name=config.AZURE_SEARCH_INDEX_NAME,
        fields=fields,
        vector_search=vector_search,
        semantic_search=semantic_search,
    )

    index_client = _get_index_client()
    result = index_client.create_or_update_index(index)
    logger.info(f"Index created/updated: {result.name}")


def upload_chunks(
    chunks: List[Chunk],
    embeddings: np.ndarray,
    batch_size: int = 100
) -> None:
    """Upload chunks with embeddings to Azure AI Search.

    Args:
        chunks: List of Chunk objects to upload
        embeddings: NumPy array of embeddings (shape: [n_chunks, embedding_dim])
        batch_size: Number of documents to upload per batch
    """
    if len(chunks) != embeddings.shape[0]:
        raise ValueError(
            f"Mismatch: {len(chunks)} chunks but {embeddings.shape[0]} embeddings"
        )

    logger.info(f"Uploading {len(chunks)} chunks to Azure AI Search")

    search_client = _get_search_client()

    # Convert chunks and embeddings to search documents
    documents = []
    for i, chunk in enumerate(chunks):
        doc = {
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
            "embedding": embeddings[i].tolist(),  # Convert numpy array to list
        }
        documents.append(doc)

    # Upload in batches
    for i in range(0, len(documents), batch_size):
        batch = documents[i:i + batch_size]
        result = search_client.upload_documents(documents=batch)

        # Check for errors
        succeeded = sum(1 for r in result if r.succeeded)
        failed = len(result) - succeeded

        logger.info(
            f"Batch {i // batch_size + 1}: {succeeded} succeeded, {failed} failed"
        )

        if failed > 0:
            for r in result:
                if not r.succeeded:
                    logger.error(f"Failed to upload {r.key}: {r.error_message}")


def search(
    query_embedding: np.ndarray,
    top_k: int = 5,
    filters: Optional[str] = None
) -> List[RetrievalResult]:
    """Perform vector similarity search in Azure AI Search.

    Args:
        query_embedding: Query embedding vector (shape: [embedding_dim])
        top_k: Number of top results to return
        filters: OData filter expression (e.g., "source_org eq 'WHO'")

    Returns:
        List of RetrievalResult objects with similarity scores
    """
    search_client = _get_search_client()

    # Perform vector search
    results = search_client.search(
        search_text=None,  # Pure vector search (no keyword search)
        vector_queries=[{
            "kind": "vector",
            "vector": query_embedding.tolist(),
            "fields": "embedding",
            "k": top_k,
        }],
        filter=filters,
        select=[
            "chunk_id", "doc_id", "doc_title", "raw_chunk",
            "ctx_header", "augmented_chunk", "section_path",
            "source_org", "source_url", "pub_date", "chunk_index"
        ],
        top=top_k,
    )

    # Convert to RetrievalResult objects
    retrieval_results = []
    for rank, result in enumerate(results, start=1):
        # Azure Search returns a similarity score
        similarity = result.get("@search.score", 0.0)

        metadata = {
            "chunk_id": result.get("chunk_id", ""),
            "doc_id": result.get("doc_id", ""),
            "doc_title": result.get("doc_title", ""),
            "raw_chunk": result.get("raw_chunk", ""),
            "ctx_header": result.get("ctx_header", ""),
            "augmented_chunk": result.get("augmented_chunk", ""),
            "section_path": result.get("section_path", ""),
            "source_org": result.get("source_org", ""),
            "source_url": result.get("source_url", ""),
            "pub_date": result.get("pub_date", ""),
            "chunk_index": result.get("chunk_index", 0),
        }

        retrieval_results.append(
            RetrievalResult(
                rank=rank,
                similarity=similarity,
                chunk_id=int(result.get("chunk_id", "0").split("_")[-1])
                if "_" in result.get("chunk_id", "")
                else 0,
                metadata=metadata,
            )
        )

    logger.info(f"Found {len(retrieval_results)} results")
    return retrieval_results


def delete_index() -> None:
    """Delete the Azure AI Search index."""
    logger.info(f"Deleting index: {config.AZURE_SEARCH_INDEX_NAME}")
    index_client = _get_index_client()
    index_client.delete_index(config.AZURE_SEARCH_INDEX_NAME)
    logger.info("Index deleted")


def get_document_count() -> int:
    """Get the number of documents in the index."""
    search_client = _get_search_client()
    # Use a simple search to get count
    results = search_client.search(search_text="*", include_total_count=True)
    return results.get_count() or 0


__all__ = [
    "create_search_index",
    "upload_chunks",
    "search",
    "delete_index",
    "get_document_count",
]
