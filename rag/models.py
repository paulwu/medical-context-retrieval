"""Dataclasses and type definitions for the RAG system."""
from __future__ import annotations
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

@dataclass
class Document:
    doc_id: str
    title: str
    content: str
    source_url: str = ""
    source_org: str = ""
    pub_date: str = ""

@dataclass
class Chunk:
    chunk_id: str
    doc_id: str
    doc_title: str
    raw_chunk: str
    chunk_index: int = 0
    ctx_header: str = ""
    augmented_chunk: str = ""
    section_path: str = ""
    source_org: str = ""
    source_url: str = ""
    pub_date: str = ""

@dataclass
class RetrievalResult:
    rank: int
    similarity: float
    chunk_id: int
    metadata: Dict[str, Any]

__all__ = [
    "Document",
    "Chunk",
    "RetrievalResult",
]
