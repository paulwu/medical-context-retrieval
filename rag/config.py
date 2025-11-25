"""Central configuration loading for the medical RAG project.

Loads environment variables from a `.env` file if present and exposes
constants with safe access patterns. This module should be imported
by other modules instead of re-reading the environment.
"""
from __future__ import annotations
import os
from pathlib import Path
from typing import Optional

from dotenv import dotenv_values  # type: ignore

# Project root resolution
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data_pilot"
PDF_DIR = DATA_DIR / "pdfs"
CACHE_DIR = PROJECT_ROOT / "cache"
for d in (DATA_DIR, PDF_DIR, CACHE_DIR):
    d.mkdir(exist_ok=True, parents=True)

_env = {}
if (PROJECT_ROOT / ".env").exists():
    # Raw load (does not mutate os.environ)
    _env = dotenv_values(PROJECT_ROOT / ".env")  # type: ignore
    # Inject into process env if not already set so downstream modules using os.getenv see them.
    for k, v in _env.items():
        if v is None:
            continue
        # strip leading/trailing whitespace (common when .env lines are indented in notebooks)
        cleaned = str(v).strip().strip('"')
        if k not in os.environ and cleaned:
            os.environ[k] = cleaned

def _normalize_endpoint(ep: str | None) -> str | None:
    if not ep:
        return ep
    ep = ep.strip().strip('/')
    # Remove legacy suffixes that newer SDKs append automatically
    for suffix in ("openai", "v1", "openai/v1"):
        if ep.lower().endswith('/' + suffix):
            ep = ep[: -(len(suffix) + 1)]
    return ep.rstrip('/')


def _get(name: str, required: bool = False, default: Optional[str] = None) -> Optional[str]:
    val = os.getenv(name) or _env.get(name) or default
    if required and not val:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return val

# Azure / OpenAI
AZURE_OPENAI_ENDPOINT = _normalize_endpoint(_get("AZURE_OPENAI_ENDPOINT", required=True))  # e.g. https://xxx.openai.azure.com
AZURE_OPENAI_API_KEY = _get("AZURE_OPENAI_API_KEY", required=True)
AOAI_EMBED_MODEL = _get("AOAI_EMBED_MODEL", required=True)
AOAI_CHAT_MODEL = _get("AOAI_CHAT_MODEL", required=True)

# Azure AI Search (for vector search - replaces FAISS)
AZURE_SEARCH_ENDPOINT = _get("AZURE_SEARCH_ENDPOINT")  # e.g. https://medctx-demo-search.search.windows.net
AZURE_SEARCH_KEY = _get("AZURE_SEARCH_KEY")
AZURE_SEARCH_INDEX_NAME = _get("AZURE_SEARCH_INDEX_NAME", default="medical-context-index")

# Azure Cosmos DB (for document/chunk storage - replaces local JSON)
COSMOS_ENDPOINT = _get("COSMOS_ENDPOINT")
COSMOS_KEY = _get("COSMOS_KEY")
COSMOS_DB_NAME = _get("COSMOS_DB_NAME", default="medical-context-db")
COSMOS_CONTAINER_DOCUMENTS = _get("COSMOS_CONTAINER_DOCUMENTS", default="documents")
COSMOS_CONTAINER_CHUNKS = _get("COSMOS_CONTAINER_CHUNKS", default="chunks")

# Storage mode: 'local' (FAISS + JSON) or 'azure' (Azure Search + Cosmos DB)
# This allows incremental migration and fallback
STORAGE_MODE = _get("STORAGE_MODE", default="local")

# Chunk / header constants (centralized)
SEMANTIC_MAX_WORDS = int(os.getenv("SEMANTIC_MAX_WORDS", 300))
HEADER_MAX_CHARS = int(os.getenv("HEADER_MAX_CHARS", 200))

# Concurrency / rate limits
REQUESTS_PER_MIN = int(os.getenv("REQUESTS_PER_MIN", 60))
TOKENS_PER_MIN = int(os.getenv("TOKENS_PER_MIN", 60000))
EST_TOKENS_PER_REQUEST = int(os.getenv("EST_TOKENS_PER_REQUEST", 200))
MAX_CONCURRENT = int(os.getenv("MAX_CONCURRENT", 8))
BATCH_SIZE = int(os.getenv("HEADER_BATCH_SIZE", 50))

# Embeddings - Conservative settings to avoid 429 errors
EMBED_BATCH_SIZE = int(os.getenv("EMBED_BATCH_SIZE", 5))  # Reduced from 10 to 5
EMBED_DELAY_SECONDS = float(os.getenv("EMBED_DELAY_SECONDS", 2.0))  # Delay between batches
EMBED_DIM_FALLBACK = int(os.getenv("EMBED_DIM_FALLBACK", 3072))  # Match text-embedding-3-large

# Persistence paths
INDEX_PATH = PROJECT_ROOT / "faiss_medical_index.bin"
CHUNK_METADATA_PATH = PROJECT_ROOT / "chunk_metadata.json"

VERSION = "0.1.0"

__all__ = [
    "PROJECT_ROOT",
    "DATA_DIR",
    "PDF_DIR",
    "CACHE_DIR",
    "AZURE_OPENAI_ENDPOINT",
    "AZURE_OPENAI_API_KEY",
    "AOAI_EMBED_MODEL",
    "AOAI_CHAT_MODEL",
    "AZURE_SEARCH_ENDPOINT",
    "AZURE_SEARCH_KEY",
    "AZURE_SEARCH_INDEX_NAME",
    "COSMOS_ENDPOINT",
    "COSMOS_KEY",
    "COSMOS_DB_NAME",
    "COSMOS_CONTAINER_DOCUMENTS",
    "COSMOS_CONTAINER_CHUNKS",
    "STORAGE_MODE",
    "SEMANTIC_MAX_WORDS",
    "HEADER_MAX_CHARS",
    "REQUESTS_PER_MIN",
    "TOKENS_PER_MIN",
    "EST_TOKENS_PER_REQUEST",
    "MAX_CONCURRENT",
    "BATCH_SIZE",
    "EMBED_BATCH_SIZE",
    "EMBED_DELAY_SECONDS",
    "EMBED_DIM_FALLBACK",
    "INDEX_PATH",
    "CHUNK_METADATA_PATH",
    "VERSION",
]
