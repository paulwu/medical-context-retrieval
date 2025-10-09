"""Async contextual header generation module.

Extracted from notebook logic; provides a clean API:

    headers = await generate_headers(documents, llm=azure_chat)

Design choices:
- Dependency injection for LLM call (`llm` coroutine) to allow testing.
- Simple token request rate limiter (dual buckets: requests + tokens).
- Document-level summary caching option placeholder (future optimization).
"""
from __future__ import annotations
import asyncio
import time
import random
from dataclasses import dataclass
from typing import Iterable, List, Dict, Callable, Awaitable, Optional
import re, collections, os

from .models import Document, Chunk
from .chunking import split_by_semantic_boundaries
from .config import (
    REQUESTS_PER_MIN,
    TOKENS_PER_MIN,
    EST_TOKENS_PER_REQUEST,
    MAX_CONCURRENT,
    BATCH_SIZE,
    HEADER_MAX_CHARS,
    SEMANTIC_MAX_WORDS,
)

# -------- Rate Limiter ---------
class AsyncRateLimiter:
    def __init__(self, requests_per_min: int, tokens_per_min: int, tokens_per_request: int):
        self.requests_per_min = requests_per_min
        self.tokens_per_min = tokens_per_min
        self.tokens_per_request = tokens_per_request
        self.request_tokens = float(requests_per_min)
        self.token_tokens = float(tokens_per_min)
        now = time.time()
        self._last_request_refill = now
        self._last_token_refill = now
        self._req_lock = asyncio.Lock()
        self._tok_lock = asyncio.Lock()

    async def _refill(self):
        now = time.time()
        async with self._req_lock:
            elapsed = now - self._last_request_refill
            add = (elapsed / 60.0) * self.requests_per_min
            self.request_tokens = min(self.requests_per_min, self.request_tokens + add)
            self._last_request_refill = now
        async with self._tok_lock:
            elapsed = now - self._last_token_refill
            add = (elapsed / 60.0) * self.tokens_per_min
            self.token_tokens = min(self.tokens_per_min, self.token_tokens + add)
            self._last_token_refill = now

    async def acquire(self):
        while True:
            await self._refill()
            async with self._req_lock:
                async with self._tok_lock:
                    if self.request_tokens >= 1 and self.token_tokens >= self.tokens_per_request:
                        self.request_tokens -= 1
                        self.token_tokens -= self.tokens_per_request
                        return
            await asyncio.sleep(0.1)

# -------- Prompt Templates (Basic vs Advanced) ---------
ADVANCED_STYLE = os.getenv("HEADER_ADVANCED", "1") == "1"

DOCUMENT_CONTEXT_PROMPT = """
<doc_title>{doc_title}</doc_title>
<summary>{doc_summary}</summary>
<keywords>{keywords}</keywords>
<position>{position_info}</position>
""".strip()

CHUNK_CONTEXT_PROMPT = """
<chunk>
{chunk_content}
</chunk>
{surrounding}

Task: Produce ONE ultra-concise (<=22 tokens) retrieval header capturing:
- Clinical/topic focus (disease / condition / population)
- Specific subtopic or action (screening, risk factor, staging, management, adverse event, prognosis, epidemiology, recommendation, dosage nuance, contraindication)
- If present: patient group / modality / phase qualifier
- Distinguish from sibling chunks; avoid generic words (section, overview, information)

Rules:
- No leading labels or numbering
- Prefer noun phrase or terse clause; can include key qualifier (e.g., pediatric, first-line)
- Do NOT copy chunk verbatim; abstract its role in the broader guideline
- Avoid repeating doc title unless necessary for specificity
Return ONLY the header text.
""".strip()

SYSTEM_MESSAGE_BASIC = (
    "You are a medical information specialist. Provide a single concise contextualizing phrase or sentence "
    "that situates the chunk within the larger medical document. Output ONLY the phrase."
)

SYSTEM_MESSAGE_ADVANCED = (
    "You generate high-signal retrieval headers for medical guideline chunks. Each header is <=22 tokens, "
    "packs global guideline context + specific subtopic nuance, excludes boilerplate, and maximizes discriminative recall value."
)

SYSTEM_MESSAGE = SYSTEM_MESSAGE_ADVANCED if ADVANCED_STYLE else SYSTEM_MESSAGE_BASIC

STOPWORDS = { 'the','and','for','with','that','this','from','are','was','were','will','into','about','your','their','there','such','these','those','than','then','have','has','had','may','can','also','been','being','within','without','between','among','over','under','more','most','some','other','which','while','where','when','what','who','whom','whose','why','how','a','an','of','to','in','on','by','it','its','as','at','or','we','our','you' }

# Truncation controls for advanced mode (prevent oversize prompts / token errors)
CHUNK_HEAD_CHARS = int(os.getenv("HEADER_CHUNK_HEAD", "850"))
CHUNK_TAIL_CHARS = int(os.getenv("HEADER_CHUNK_TAIL", "350"))
NEIGHBOR_SNIP_CHARS = int(os.getenv("HEADER_NEIGHBOR_CHARS", "140"))
DOC_SUMMARY_CHARS = int(os.getenv("HEADER_DOC_SUMMARY_CHARS", "600"))
KEYWORD_COUNT = int(os.getenv("HEADER_KEYWORD_COUNT", "12"))

def _extract_keywords(text: str, k: int = KEYWORD_COUNT) -> List[str]:
    text = re.sub(r"[^A-Za-z0-9\s]", " ", text.lower())
    tokens = [t for t in text.split() if len(t) > 3 and t not in STOPWORDS]
    freq = collections.Counter(tokens)
    boosted = {}
    for w, c in freq.items():
        bonus = 0
        if any(suf in w for suf in ("itis","osis","emia","pathy","genic","therapy","lysis","oma")):
            bonus += 2
        if any(s in w for s in ("onc", "cardio", "neuro", "hepat", "renal", "derm", "pulmo", "immun")):
            bonus += 1
        boosted[w] = c + bonus
    top = sorted(boosted.items(), key=lambda x: x[1], reverse=True)[:k]
    return [w for w,_ in top]

def _summarize_doc_head(text: str, max_chars: int = DOC_SUMMARY_CHARS) -> str:
    return re.sub(r"\s+"," ", text.strip())[:max_chars]

def _slice_for_header(text: str) -> str:
    """Return a condensed representation of a chunk for header generation.

    Strategy: head + ellipsis + tail if long. Keeps salient opening defs + concluding recommendation cues.
    """
    t = text.strip()
    if len(t) <= CHUNK_HEAD_CHARS + CHUNK_TAIL_CHARS + 20:
        return t
    head = t[:CHUNK_HEAD_CHARS]
    tail = t[-CHUNK_TAIL_CHARS:]
    return head + " ... " + tail

# -------- Core Logic ---------
async def _generate_header(llm: Callable[[List[Dict]], Awaitable[str]], chunk_payload: Dict, limiter: AsyncRateLimiter, retries: int = 4):
    attempt = 0
    last_error = None
    while attempt < retries:
        await limiter.acquire()
        try:
            if ADVANCED_STYLE:
                surrounding_parts = []
                prev_snip = chunk_payload.get("prev_text", "")[:NEIGHBOR_SNIP_CHARS]
                next_snip = chunk_payload.get("next_text", "")[:NEIGHBOR_SNIP_CHARS]
                if prev_snip:
                    surrounding_parts.append(f"<prev>{prev_snip}</prev>")
                if next_snip:
                    surrounding_parts.append(f"<next>{next_snip}</next>")
                surrounding = "\n".join(surrounding_parts)
                content = DOCUMENT_CONTEXT_PROMPT.format(
                    doc_title=chunk_payload.get("doc_title",""),
                    doc_summary=chunk_payload.get("doc_summary",""),
                    keywords=chunk_payload.get("keywords",""),
                    position_info=chunk_payload.get("position",""),
                ) + "\n" + CHUNK_CONTEXT_PROMPT.format(chunk_content=_slice_for_header(chunk_payload["text"]), surrounding=surrounding)
            else:
                content = f"<document>{chunk_payload['doc_content']}</document>\n<chunk>{_slice_for_header(chunk_payload['text'])}</chunk>\nProvide a concise context phrase."  # legacy simplified
            messages = [
                {"role": "system", "content": SYSTEM_MESSAGE},
                {"role": "user", "content": content},
            ]
            header = await llm(messages)
            header = header.replace("\n", " ").strip()

            # If LLM returned empty/whitespace, treat as failure and retry
            if not header:
                raise ValueError("LLM returned empty header")

            if len(header) > HEADER_MAX_CHARS:
                header = header[: HEADER_MAX_CHARS - 3].rstrip() + "..."
            return header
        except Exception as e:  # pragma: no cover - network variability
            last_error = e
            backoff = (2 ** attempt) + random.uniform(0, 1)
            await asyncio.sleep(backoff)
            attempt += 1

    # Log the failure before returning fallback with document context
    section = chunk_payload.get('section_path', 'Section')
    doc_title = chunk_payload.get('doc_title', 'document')
    print(f"⚠️  Header generation failed after {retries} attempts for {section}: {last_error}", flush=True)
    # Include document title in fallback for better context
    return f"{doc_title} — {section}"

async def generate_headers(
    documents: Iterable[Document],
    llm: Callable[[List[Dict]], Awaitable[str]],
    semantic_max_words: int = SEMANTIC_MAX_WORDS,
    batch_size: int = BATCH_SIZE,
    max_concurrent: int = MAX_CONCURRENT,
    progress_callback: Optional[Callable[[str, int, int, float, float, float], None]] = None,
    use_tqdm: bool = False,
) -> List[Chunk]:
    """Generate contextual headers for all semantic chunks across documents.

    Parameters
    ----------
    documents : Iterable[Document]
        Source documents.
    llm : coroutine(messages) -> str
        Async LLM chat completion adapter returning a header string.
    semantic_max_words : int
        Approximate max words per semantic chunk.
    batch_size : int
        Number of coroutine tasks to gather per await (throttles memory / progress cadence).
    max_concurrent : int
        Upper bound on simultaneous in-flight LLM requests.
    progress_callback : callable(phase, done, total, pct, rate, eta)
        Optional progress reporter. Phases: 'prepare', 'headers'.
    use_tqdm : bool
        If True and no progress_callback provided, show local tqdm bars.
    """
    limiter = AsyncRateLimiter(REQUESTS_PER_MIN, TOKENS_PER_MIN, EST_TOKENS_PER_REQUEST)
    semaphore = asyncio.Semaphore(max_concurrent)
    chunks_out: List[Chunk] = []

    # Optional tqdm setup
    tqdm_prepare = tqdm_headers = None
    if progress_callback is None and use_tqdm:
        try:  # pragma: no cover - optional dependency
            from tqdm.auto import tqdm  # type: ignore
            tqdm_prepare = tqdm(total=0, desc="Prepare", leave=False)
        except Exception:
            pass

    # -------- Preparation: build task payloads & count total --------
    tasks: List[Awaitable[None]] = []
    total_chunks = 0
    doc_index = 0
    for doc in documents:
        semantic_chunks = split_by_semantic_boundaries(doc.content, semantic_max_words)
        if ADVANCED_STYLE:
            doc_summary = _summarize_doc_head(doc.content)
            kw = ", ".join(_extract_keywords(doc.content))
        total_in_doc = len(semantic_chunks) or 1
        for i, info in enumerate(semantic_chunks):
            info["section_path"] = f"Section {i+1}"
            if ADVANCED_STYLE:
                pct = (i+1)/total_in_doc*100
                info.update({
                    "doc_title": doc.title,
                    "doc_summary": doc_summary,
                    "keywords": kw,
                    "position": f"chunk {i+1} of {total_in_doc} (~{pct:0.1f}% doc)",
                })
                if i>0:
                    info["prev_text"] = semantic_chunks[i-1]['text']
                if i < total_in_doc-1:
                    info["next_text"] = semantic_chunks[i+1]['text']
            info["doc_content"] = doc.content[:30000]
            payload = dict(info)
            async def run_one(doc_ref=doc, idx=i, payload_ref=payload):
                async with semaphore:
                    header = await _generate_header(llm, payload_ref, limiter)
                    augmented = f"{header}\n\n{payload_ref['text']}"
                    chunk = Chunk(
                        chunk_id=f"{doc_ref.doc_id}_chunk_{idx}",
                        doc_id=doc_ref.doc_id,
                        doc_title=doc_ref.title,
                        raw_chunk=payload_ref['text'],
                        chunk_index=idx,
                        ctx_header=header,
                        augmented_chunk=augmented,
                        section_path=payload_ref.get('section_path',''),
                        source_org=doc_ref.source_org,
                        source_url=doc_ref.source_url,
                        pub_date=doc_ref.pub_date,
                    )
                    chunks_out.append(chunk)
            tasks.append(run_one())
            total_chunks += 1
        doc_index += 1
        if tqdm_prepare:
            tqdm_prepare.total = doc_index  # track docs processed
            tqdm_prepare.update(1)
        if progress_callback:
            progress_callback("prepare", doc_index, -1, 0.0, 0.0, float('inf'))

    if tqdm_prepare:
        tqdm_prepare.close()

    # Early exit
    if total_chunks == 0:
        if progress_callback:
            progress_callback("headers", 0, 0, 0.0, 0.0, 0.0)
        return []

    # Setup header progress
    start_time = time.time()
    last_report_time = start_time
    done = 0
    if progress_callback:
        progress_callback("headers", 0, total_chunks, 0.0, 0.0, float('inf'))
    elif use_tqdm and tqdm_headers is None:
        try:  # pragma: no cover
            from tqdm.auto import tqdm  # type: ignore
            tqdm_headers = tqdm(total=total_chunks, desc="Headers", leave=True)
        except Exception:
            pass

    # -------- Execute with streaming progress (as_completed) --------
    # We process tasks in slices (batches) to avoid huge task lists overwhelming loop,
    # but within each slice we stream completion updates.
    from itertools import islice
    task_iter = iter(tasks)
    BATCH_SLICE = batch_size  # reuse batch_size for slice width
    pending: List[asyncio.Task] = []

    async def consume_slice():
        nonlocal pending
        slice_tasks = list(islice(task_iter, BATCH_SLICE))
        if not slice_tasks:
            return False
        # wrap each in ensure_future so we can await as_completed
        pending.extend([asyncio.ensure_future(t) for t in slice_tasks])
        return True

    # prime first slice
    await consume_slice()

    while pending:
        # Wait for first task to finish
        done_set, pending_set = await asyncio.wait(pending, return_when=asyncio.FIRST_COMPLETED)
        # Update pending list
        pending = list(pending_set)
        # Refill if we have capacity (keep roughly <= 2*BATCH_SLICE queued)
        if len(pending) < BATCH_SLICE:
            await consume_slice()
        # Update progress once per completion group
        done = len(chunks_out)
        now = time.time()
        elapsed = now - start_time
        rate = done / elapsed if elapsed > 0 else 0.0
        remaining = total_chunks - done
        eta = remaining / rate if rate > 0 else float('inf')
        pct = (done / total_chunks) * 100.0
        if progress_callback:
            if (now - last_report_time) > 0.2 or done == total_chunks or done <= 5:
                progress_callback("headers", done, total_chunks, pct, rate, eta)
                last_report_time = now
        elif tqdm_headers:
            tqdm_headers.update(done - tqdm_headers.n)
            tqdm_headers.set_postfix(rate=f"{rate:.2f}/s")
        else:
            if (now - last_report_time) > 1 or done == total_chunks or done <= 5:
                print(f"[headers] {done}/{total_chunks} ({pct:5.1f}%) rate={rate:.2f}/s ETA={'∞' if eta==float('inf') else f'{eta:.1f}s'}", flush=True)
                last_report_time = now

    if tqdm_headers:
        tqdm_headers.close()
    return chunks_out

# -------- Example LLM adapter (async) ---------
async def azure_chat_completion(messages: List[Dict], model: str | None = None):  # placeholder; real impl in separate llm module later
    from openai import AsyncAzureOpenAI  # type: ignore
    from .config import AZURE_OPENAI_API_KEY, AZURE_OPENAI_ENDPOINT, AOAI_CHAT_MODEL
    client = AsyncAzureOpenAI(api_key=AZURE_OPENAI_API_KEY, azure_endpoint=AZURE_OPENAI_ENDPOINT, api_version="2024-08-01-preview")
    # Use higher token limit for reasoning models like gpt-5-mini that use tokens for internal reasoning
    # Increased from 500 to 800 to handle longer contextual headers
    resp = await client.chat.completions.create(
        model=model or AOAI_CHAT_MODEL,
        messages=messages,
        max_completion_tokens=800
    )
    content = resp.choices[0].message.content
    return content.strip() if content else ""

__version__ = "0.2.0-progress-callback"


class ContextualHeaderGenerator:
    """Synchronous wrapper for contextual header generation."""

    def __init__(self, llm_func=None):
        """Initialize the header generator.

        Args:
            llm_func: Optional LLM function. If None, uses azure_chat_completion.
        """
        self.llm_func = llm_func or azure_chat_completion

    def generate_headers_batch(self, chunks: List[Chunk], batch_size: int = BATCH_SIZE) -> List[Chunk]:
        """Generate contextual headers for a batch of chunks (synchronous).

        Args:
            chunks: List of Chunk objects (already chunked)
            batch_size: Number of chunks to process in parallel

        Returns:
            List of Chunk objects with ctx_header filled in
        """
        # For already-chunked data, we need to reconstruct documents
        # and pass them to generate_headers which will re-chunk internally
        # This is not ideal but matches the existing API

        # Group chunks by document
        doc_map = {}
        for chunk in chunks:
            if chunk.doc_id not in doc_map:
                doc_map[chunk.doc_id] = {
                    'doc': Document(
                        doc_id=chunk.doc_id,
                        title=chunk.doc_title,
                        content="",  # Will be built from chunks
                        source_url=chunk.source_url
                    ),
                    'chunks': []
                }
            doc_map[chunk.doc_id]['chunks'].append(chunk)

        # Reconstruct document content from chunks
        documents = []
        for doc_data in doc_map.values():
            # Sort chunks by index and concatenate
            sorted_chunks = sorted(doc_data['chunks'], key=lambda c: c.chunk_index)
            content = "\n\n".join(c.raw_chunk for c in sorted_chunks)
            doc_data['doc'].content = content
            documents.append(doc_data['doc'])

        # Run async function in event loop
        # Use nest_asyncio to allow nested event loops in Jupyter
        try:
            import nest_asyncio
            nest_asyncio.apply()
        except ImportError:
            pass

        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

        result_chunks = loop.run_until_complete(
            generate_headers(
                documents=documents,
                llm=self.llm_func,
                batch_size=batch_size
            )
        )

        return result_chunks


__all__ = [
    "generate_headers",
    "azure_chat_completion",
    "ContextualHeaderGenerator",
    "__version__",
]
