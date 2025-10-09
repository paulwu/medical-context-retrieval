"""Semantic chunking utilities.

Initial simple implementation mirrors existing logic (paragraph grouping) but
is modular so it can be swapped for more advanced approaches later.
"""
from __future__ import annotations
from typing import List, Dict
import re
import uuid

from .config import SEMANTIC_MAX_WORDS
from .models import Document, Chunk

__all__ = ["split_by_semantic_boundaries", "SemanticChunker"]

def _normalize_whitespace(text: str) -> str:
    return re.sub(r"\s+", " ", text or "").strip()

def split_by_semantic_boundaries(text: str, max_words: int = SEMANTIC_MAX_WORDS) -> List[Dict]:
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    chunks: List[Dict] = []
    cur = []
    cur_words = 0
    for para in paragraphs:
        w = len(para.split())
        if cur and cur_words + w > max_words:
            combined = "\n\n".join(cur).strip()
            chunks.append({"text": _normalize_whitespace(combined), "word_count": cur_words})
            cur = [para]
            cur_words = w
        else:
            cur.append(para)
            cur_words += w
    if cur:
        combined = "\n\n".join(cur).strip()
        chunks.append({"text": _normalize_whitespace(combined), "word_count": cur_words})
    return chunks


class SemanticChunker:
    """Semantic chunker that splits documents into chunks with semantic boundaries."""

    def __init__(self, max_words: int = SEMANTIC_MAX_WORDS):
        self.max_words = max_words

    def chunk_documents(self, documents: List[Document]) -> List[Chunk]:
        """Chunk a list of documents.

        Args:
            documents: List of Document objects to chunk

        Returns:
            List of Chunk objects
        """
        all_chunks = []

        for doc in documents:
            chunk_dicts = split_by_semantic_boundaries(doc.content, self.max_words)

            for idx, chunk_dict in enumerate(chunk_dicts):
                chunk = Chunk(
                    chunk_id=uuid.uuid4().hex,
                    doc_id=doc.doc_id,
                    doc_title=doc.title,
                    source_url=doc.source_url,
                    chunk_index=idx,
                    raw_chunk=chunk_dict["text"],
                    ctx_header=""  # Will be filled in by header generation
                )
                all_chunks.append(chunk)

        return all_chunks
