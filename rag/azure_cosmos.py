"""Azure Cosmos DB integration for document and chunk storage (replaces local JSON).

This module provides functions to:
1. Initialize Cosmos DB database and containers
2. Save/load documents and chunks to/from Cosmos DB
3. Query and manage stored data
"""
from __future__ import annotations
import logging
from typing import List, Optional, Dict, Any

from azure.cosmos import CosmosClient, PartitionKey, exceptions
from azure.cosmos.container import ContainerProxy
from azure.cosmos.database import DatabaseProxy

from . import config
from .models import Document, Chunk

logger = logging.getLogger(__name__)


def _get_cosmos_client() -> CosmosClient:
    """Get Cosmos DB client."""
    if not config.COSMOS_ENDPOINT or not config.COSMOS_KEY:
        raise RuntimeError(
            "Cosmos DB not configured. Set COSMOS_ENDPOINT and COSMOS_KEY"
        )

    return CosmosClient(
        url=config.COSMOS_ENDPOINT,
        credential=config.COSMOS_KEY
    )


def _get_database() -> DatabaseProxy:
    """Get or create the Cosmos DB database."""
    client = _get_cosmos_client()

    try:
        database = client.create_database_if_not_exists(id=config.COSMOS_DB_NAME)
        logger.info(f"Using database: {config.COSMOS_DB_NAME}")
        return database
    except exceptions.CosmosHttpResponseError as e:
        logger.error(f"Failed to create/get database: {e}")
        raise


def _get_container(container_name: str) -> ContainerProxy:
    """Get or create a Cosmos DB container.

    Args:
        container_name: Name of the container to get/create

    Returns:
        ContainerProxy for the requested container
    """
    database = _get_database()

    try:
        # Create container with partition key on 'id' for simple partitioning
        # Note: offer_throughput is not set for serverless accounts
        container = database.create_container_if_not_exists(
            id=container_name,
            partition_key=PartitionKey(path="/id")
        )
        logger.info(f"Using container: {container_name}")
        return container
    except exceptions.CosmosHttpResponseError as e:
        logger.error(f"Failed to create/get container {container_name}: {e}")
        raise


def init_cosmos_db() -> None:
    """Initialize Cosmos DB database and containers."""
    logger.info("Initializing Cosmos DB...")

    # Create database and containers
    _get_container(config.COSMOS_CONTAINER_DOCUMENTS)
    _get_container(config.COSMOS_CONTAINER_CHUNKS)

    logger.info("Cosmos DB initialized successfully")


def save_documents(documents: List[Document]) -> None:
    """Save documents to Cosmos DB.

    Args:
        documents: List of Document objects to save
    """
    if not documents:
        logger.warning("No documents to save")
        return

    logger.info(f"Saving {len(documents)} documents to Cosmos DB")

    container = _get_container(config.COSMOS_CONTAINER_DOCUMENTS)

    for doc in documents:
        # Convert Document to dict for Cosmos DB
        doc_dict = {
            "id": doc.doc_id,  # Cosmos DB requires 'id' field
            "doc_id": doc.doc_id,
            "title": doc.title,
            "content": doc.content,
            "source_url": doc.source_url,
            "source_org": doc.source_org,
            "pub_date": doc.pub_date,
        }

        try:
            # Upsert (create or update) the document
            container.upsert_item(doc_dict)
        except exceptions.CosmosHttpResponseError as e:
            logger.error(f"Failed to save document {doc.doc_id}: {e}")
            raise

    logger.info(f"Successfully saved {len(documents)} documents")


def load_documents() -> List[Document]:
    """Load all documents from Cosmos DB.

    Returns:
        List of Document objects
    """
    logger.info("Loading documents from Cosmos DB")

    container = _get_container(config.COSMOS_CONTAINER_DOCUMENTS)

    try:
        # Query all documents
        items = list(container.read_all_items())

        # Convert to Document objects
        documents = [
            Document(
                doc_id=item["doc_id"],
                title=item.get("title", ""),
                content=item.get("content", ""),
                source_url=item.get("source_url", ""),
                source_org=item.get("source_org", ""),
                pub_date=item.get("pub_date", ""),
            )
            for item in items
        ]

        logger.info(f"Loaded {len(documents)} documents")
        return documents

    except exceptions.CosmosHttpResponseError as e:
        logger.error(f"Failed to load documents: {e}")
        raise


def save_chunks(chunks: List[Chunk]) -> None:
    """Save chunks to Cosmos DB.

    Args:
        chunks: List of Chunk objects to save
    """
    if not chunks:
        logger.warning("No chunks to save")
        return

    logger.info(f"Saving {len(chunks)} chunks to Cosmos DB")

    container = _get_container(config.COSMOS_CONTAINER_CHUNKS)

    for chunk in chunks:
        # Convert Chunk to dict for Cosmos DB
        chunk_dict = {
            "id": chunk.chunk_id,  # Cosmos DB requires 'id' field
            "chunk_id": chunk.chunk_id,
            "doc_id": chunk.doc_id,
            "doc_title": chunk.doc_title,
            "raw_chunk": chunk.raw_chunk,
            "chunk_index": chunk.chunk_index,
            "ctx_header": chunk.ctx_header,
            "augmented_chunk": chunk.augmented_chunk,
            "section_path": chunk.section_path,
            "source_org": chunk.source_org,
            "source_url": chunk.source_url,
            "pub_date": chunk.pub_date,
        }

        try:
            # Upsert (create or update) the chunk
            container.upsert_item(chunk_dict)
        except exceptions.CosmosHttpResponseError as e:
            logger.error(f"Failed to save chunk {chunk.chunk_id}: {e}")
            raise

    logger.info(f"Successfully saved {len(chunks)} chunks")


def load_chunks() -> List[Chunk]:
    """Load all chunks from Cosmos DB.

    Returns:
        List of Chunk objects
    """
    logger.info("Loading chunks from Cosmos DB")

    container = _get_container(config.COSMOS_CONTAINER_CHUNKS)

    try:
        # Query all chunks
        items = list(container.read_all_items())

        # Convert to Chunk objects
        chunks = [
            Chunk(
                chunk_id=item["chunk_id"],
                doc_id=item.get("doc_id", ""),
                doc_title=item.get("doc_title", ""),
                raw_chunk=item.get("raw_chunk", ""),
                chunk_index=item.get("chunk_index", 0),
                ctx_header=item.get("ctx_header", ""),
                augmented_chunk=item.get("augmented_chunk", ""),
                section_path=item.get("section_path", ""),
                source_org=item.get("source_org", ""),
                source_url=item.get("source_url", ""),
                pub_date=item.get("pub_date", ""),
            )
            for item in items
        ]

        logger.info(f"Loaded {len(chunks)} chunks")
        return chunks

    except exceptions.CosmosHttpResponseError as e:
        logger.error(f"Failed to load chunks: {e}")
        raise


def get_document_by_id(doc_id: str) -> Optional[Document]:
    """Get a specific document by ID.

    Args:
        doc_id: Document ID to retrieve

    Returns:
        Document object or None if not found
    """
    container = _get_container(config.COSMOS_CONTAINER_DOCUMENTS)

    try:
        item = container.read_item(item=doc_id, partition_key=doc_id)
        return Document(
            doc_id=item["doc_id"],
            title=item.get("title", ""),
            content=item.get("content", ""),
            source_url=item.get("source_url", ""),
            source_org=item.get("source_org", ""),
            pub_date=item.get("pub_date", ""),
        )
    except exceptions.CosmosResourceNotFoundError:
        logger.warning(f"Document {doc_id} not found")
        return None
    except exceptions.CosmosHttpResponseError as e:
        logger.error(f"Failed to get document {doc_id}: {e}")
        raise


def get_chunks_by_doc_id(doc_id: str) -> List[Chunk]:
    """Get all chunks for a specific document.

    Args:
        doc_id: Document ID to get chunks for

    Returns:
        List of Chunk objects for the document
    """
    container = _get_container(config.COSMOS_CONTAINER_CHUNKS)

    try:
        # Query chunks by doc_id
        query = "SELECT * FROM c WHERE c.doc_id = @doc_id"
        items = list(container.query_items(
            query=query,
            parameters=[{"name": "@doc_id", "value": doc_id}],
            enable_cross_partition_query=True
        ))

        chunks = [
            Chunk(
                chunk_id=item["chunk_id"],
                doc_id=item.get("doc_id", ""),
                doc_title=item.get("doc_title", ""),
                raw_chunk=item.get("raw_chunk", ""),
                chunk_index=item.get("chunk_index", 0),
                ctx_header=item.get("ctx_header", ""),
                augmented_chunk=item.get("augmented_chunk", ""),
                section_path=item.get("section_path", ""),
                source_org=item.get("source_org", ""),
                source_url=item.get("source_url", ""),
                pub_date=item.get("pub_date", ""),
            )
            for item in items
        ]

        return chunks

    except exceptions.CosmosHttpResponseError as e:
        logger.error(f"Failed to get chunks for document {doc_id}: {e}")
        raise


def delete_all_documents() -> None:
    """Delete all documents from Cosmos DB (use with caution)."""
    logger.warning("Deleting all documents from Cosmos DB")
    container = _get_container(config.COSMOS_CONTAINER_DOCUMENTS)

    items = list(container.read_all_items())
    for item in items:
        container.delete_item(item=item["id"], partition_key=item["id"])

    logger.info(f"Deleted {len(items)} documents")


def delete_all_chunks() -> None:
    """Delete all chunks from Cosmos DB (use with caution)."""
    logger.warning("Deleting all chunks from Cosmos DB")
    container = _get_container(config.COSMOS_CONTAINER_CHUNKS)

    items = list(container.read_all_items())
    for item in items:
        container.delete_item(item=item["id"], partition_key=item["id"])

    logger.info(f"Deleted {len(items)} chunks")


def get_stats() -> Dict[str, Any]:
    """Get statistics about stored data.

    Returns:
        Dictionary with document and chunk counts
    """
    doc_container = _get_container(config.COSMOS_CONTAINER_DOCUMENTS)
    chunk_container = _get_container(config.COSMOS_CONTAINER_CHUNKS)

    doc_count = len(list(doc_container.read_all_items(max_item_count=1)))
    chunk_count = len(list(chunk_container.read_all_items(max_item_count=1)))

    return {
        "document_count": doc_count,
        "chunk_count": chunk_count,
        "database": config.COSMOS_DB_NAME,
        "documents_container": config.COSMOS_CONTAINER_DOCUMENTS,
        "chunks_container": config.COSMOS_CONTAINER_CHUNKS,
    }


__all__ = [
    "init_cosmos_db",
    "save_documents",
    "load_documents",
    "save_chunks",
    "load_chunks",
    "get_document_by_id",
    "get_chunks_by_doc_id",
    "delete_all_documents",
    "delete_all_chunks",
    "get_stats",
]
