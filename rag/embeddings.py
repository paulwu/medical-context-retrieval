"""Embedding utilities wrapping Azure OpenAI embedding API.

Keeps a single function `get_embeddings_batch` that other modules can import.
Provides robust retry logic with exponential backoff for rate limits (429 errors)
and returns zero vectors on failure to avoid crashing downstream logic during exploratory work.
"""
from __future__ import annotations
from typing import List, Sequence
import os
import time
import random
import numpy as np

from .config import AOAI_EMBED_MODEL, EMBED_DIM_FALLBACK

try:  # pragma: no cover - import variability
    from openai import OpenAI, AzureOpenAI  # type: ignore
except ImportError:  # graceful degradation
    OpenAI = AzureOpenAI = None  # type: ignore

_client = None

def get_client():
    """Return a singleton embedding client.

    Resolution order:
    1. If standard OPENAI_API_KEY set -> use public OpenAI endpoint.
    2. Else if AZURE_OPENAI_API_KEY + AZURE_OPENAI_ENDPOINT -> use AzureOpenAI with key.
    3. Else if AZURE_OPENAI_ENDPOINT set (no key) -> use AzureOpenAI with managed identity.
    4. Else if EMBED_ZERO_ON_MISSING=1 -> return a dummy sentinel to trigger zero-vector fallback.
    5. Else raise a clear credential error.
    """
    global _client
    if _client is not None:
        return _client

    openai_key = os.getenv("OPENAI_API_KEY")
    az_key = os.getenv("AZURE_OPENAI_API_KEY")
    az_ep = os.getenv("AZURE_OPENAI_ENDPOINT")
    api_version = os.getenv("AZURE_OPENAI_API_VERSION", "2024-08-01-preview")

    if openai_key and OpenAI:
        _client = OpenAI(api_key=openai_key)
        return _client
    if az_key and az_ep and AzureOpenAI:
        _client = AzureOpenAI(api_key=az_key, azure_endpoint=az_ep, api_version=api_version)
        return _client
    if az_ep and AzureOpenAI:
        # Managed identity / DefaultAzureCredential (no API key required)
        try:
            from azure.identity import DefaultAzureCredential, get_bearer_token_provider
            credential = DefaultAzureCredential()
            token_provider = get_bearer_token_provider(
                credential, "https://cognitiveservices.azure.com/.default"
            )
            _client = AzureOpenAI(
                azure_ad_token_provider=token_provider,
                azure_endpoint=az_ep,
                api_version=api_version,
            )
            return _client
        except ImportError:
            raise RuntimeError(
                "azure-identity package required for managed identity auth. "
                "Install with: pip install azure-identity"
            )

    if os.getenv("EMBED_ZERO_ON_MISSING", "0") == "1":
        class _Dummy:
            def embeddings(self):  # type: ignore
                raise RuntimeError("Dummy embeddings client should not be called directly")
        _client = _Dummy()  # sentinel
        return _client

    raise RuntimeError(
        "No embedding credentials found. Set OPENAI_API_KEY, or AZURE_OPENAI_API_KEY + AZURE_OPENAI_ENDPOINT, "
        "or just AZURE_OPENAI_ENDPOINT for managed identity auth. "
        "Optionally set EMBED_ZERO_ON_MISSING=1 to return zero vectors instead of failing."
    )


def get_embeddings_batch(texts: Sequence[str], model: str = AOAI_EMBED_MODEL, max_retries: int = 5) -> List[List[float]]:
    if not texts:
        return []
    try:
        client = get_client()
    except RuntimeError as cred_err:
        # Explicit credentials error -> surface once then zero-fallback
        print(f"[embeddings] credential error: {cred_err}")
        return [[0.0] * EMBED_DIM_FALLBACK for _ in texts]

    # If dummy sentinel, short-circuit
    if client.__class__.__name__ == '_Dummy':  # type: ignore
        return [[0.0] * EMBED_DIM_FALLBACK for _ in texts]

    # Robust retry with exponential backoff for rate limits
    for attempt in range(max_retries):
        try:
            resp = client.embeddings.create(input=list(texts), model=model)
            return [d.embedding for d in resp.data]
        except Exception as e:
            error_str = str(e).lower()
            
            # Handle rate limit errors (429) with exponential backoff
            if "429" in error_str or "rate limit" in error_str or "too many requests" in error_str:
                if attempt < max_retries - 1:  # Don't sleep on final attempt
                    # Exponential backoff: 2^attempt + jitter, capped at 60s
                    delay = min(2 ** attempt + random.uniform(0, 1), 60)
                    print(f"[embeddings] Rate limit hit (attempt {attempt + 1}/{max_retries}), waiting {delay:.1f}s...")
                    time.sleep(delay)
                    continue
                else:
                    print(f"[embeddings] Rate limit exceeded after {max_retries} attempts")
            
            # Handle other errors with shorter backoff
            elif attempt < max_retries - 1:
                delay = min(2 ** attempt, 10)  # Shorter backoff for other errors
                print(f"[embeddings] Error (attempt {attempt + 1}/{max_retries}): {e}")
                print(f"[embeddings] Retrying in {delay:.1f}s...")
                time.sleep(delay)
                continue
            else:
                print(f"[embeddings] Failed after {max_retries} attempts: {e}")
            
        # If we reach here, all retries failed
        return [[0.0] * EMBED_DIM_FALLBACK for _ in texts]
    
    # Fallback (shouldn't reach here)
    return [[0.0] * EMBED_DIM_FALLBACK for _ in texts]

def generate_embeddings(texts: Sequence[str], model: str = AOAI_EMBED_MODEL) -> List[List[float]]:
    """Alias for get_embeddings_batch for compatibility with existing pipeline code."""
    return get_embeddings_batch(texts, model)

__all__ = ["get_embeddings_batch", "generate_embeddings"]
