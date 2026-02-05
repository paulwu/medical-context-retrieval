# Medical Context Retrieval System - Purpose

## 🎯 Problem Being Solved

When searching medical guidelines with standard vector search or generic LLMs:

- **Context is lost** - A chunk like *"The patient should follow these guidelines for optimal outcomes"* could be about diabetes, cancer, or asthma
- **LLMs can hallucinate** medical information with no verifiable sources
- **Generic search** doesn't understand medical document structure

## 💡 Key Innovation: Contextual Headers

The system adds **hierarchical section context** to each chunk before embedding:

**Without context:**
> "The patient should follow these guidelines for optimal outcomes."

**With contextual headers:**
> **Context:** NIH/NHLBI → Asthma Management Guidelines → Long-term Control → Inhaled Corticosteroids  
> "The patient should follow these guidelines for optimal outcomes."

This measurably improves retrieval accuracy because the embedding now captures *where* the information comes from.

## 🏗️ Architecture

| Mode | Vector Search | Storage | Use Case |
|------|--------------|---------|----------|
| **Local** | FAISS | JSON files in `cache/` | Learning, development, offline |
| **Azure** | Azure AI Search (HNSW) | Cosmos DB | Production, scalable |

## 📚 Data Sources

- **NCI PDQ** - Cancer treatment protocols
- **USPSTF** - Screening recommendations  
- **NHLBI** - Cardiovascular guidelines

## 🖥️ Components

| File | Description |
|------|-------------|
| `demo.ipynb` | Customer-facing interactive demo |
| `admin.ipynb` | System management (build index, scrape sources) |
| `rag/` | Core RAG modules (chunking, embeddings, retrieval) |

## 🚀 What This Demonstrates

1. **Domain-specific RAG** - How to build AI search tailored to a specific field (medical guidelines)
2. **Contextual embeddings** - Improving retrieval by preserving document hierarchy
3. **Source attribution** - Every answer links back to authoritative medical sources
4. **Dual deployment** - Same codebase works locally (FAISS) or at scale (Azure)
5. **Interactive demos** - Using Voilà to create customer-ready notebook interfaces
