# Medical Context Retrieval System

An AI-powered Retrieval-Augmented Generation (RAG) system for medical guideline search, featuring contextual header enhancement for improved retrieval accuracy.

## 🚀 Quick Local Demo

Run the interactive demo with Voilà:
```bash
pip install -r requirements.txt
voila demo.ipynb --template=lab --VoilaConfiguration.file_whitelist="['.*']"
```

The demo will launch in your browser with a clean, interactive interface for searching medical guidelines.

## 📁 Project Structure

```
medical-context-retrieval/
├── demo.ipynb              # 🎯 Clean customer-facing demo notebook
├── main.ipynb              # 🔧 Development/technical notebook
├── rag/                    # Core RAG system modules
│   ├── config.py           # Configuration and environment
│   ├── models.py           # Data models (Document, Chunk, etc.)
│   ├── embeddings.py       # Azure OpenAI embedding utilities
│   ├── index.py            # FAISS vector index management
│   ├── retrieval.py        # EmbeddingRetriever class
│   ├── headers.py          # Contextual header generation
│   ├── chunking.py         # Document chunking logic
│   ├── scrape.py           # Web scraping utilities
│   ├── cache.py            # Caching and persistence
│   └── eval/               # Evaluation metrics and benchmarks
├── voila_config/           # Voilà styling and configuration
│   ├── voila.json          # Voilà settings
│   └── static/
│       └── custom.css      # Healthcare-themed styling
├── examples/               # Demo query examples
│   ├── sample_queries.json # Curated queries for demos
│   └── README.md           # Demo strategy guide
├── artifacts/              # Technical artifacts (moved from root)
│   ├── faiss_medical_index.bin
│   ├── header_impact_evaluation.json
│   └── retrieval_benchmark_results.json
├── cache/                  # Cached chunks and embeddings
├── data_pilot/             # Source medical documents
└── requirements.txt        # Python dependencies
```

## 🎯 Key Features

### 1. **Contextual Header Enhancement**
- Proprietary header generation system provides semantic context to document chunks
- Measurably improves retrieval accuracy over baseline vector search
- Generates hierarchical context from document structure

### 2. **Multi-Source Medical Guidelines**
- **NCI PDQ** (National Cancer Institute) - Cancer treatment protocols
- **USPSTF** (U.S. Preventive Services Task Force) - Screening recommendations
- **NHLBI** (National Heart, Lung, and Blood Institute) - Cardiovascular guidelines

### 3. **Interactive Demo Interface**
- Clean, professional UI built with Voilà and ipywidgets
- Real-time search with confidence scores
- Color-coded relevance indicators (green/yellow/red)
- Source citations for all results
- Example queries for quick demos

### 4. **Performance Metrics**
- Quantified improvement from header enhancement
- Comprehensive evaluation framework
- A/B testing capabilities (baseline vs. enhanced)

## 🏥 Use Cases

- **Healthcare Organizations**: Build domain-specific AI systems with better accuracy than commercial alternatives
- **Clinical Decision Support**: Fast, accurate retrieval of guideline information
- **Medical Education**: Interactive exploration of clinical guidelines
- **Research**: Demonstrate RAG techniques for medical information retrieval

## 🛠️ Technology Stack

- **Embeddings**: Azure OpenAI (text-embedding-ada-002)
- **Vector Search**: FAISS (Facebook AI Similarity Search)
- **NLP**: OpenAI GPT models for header generation
- **Frontend**: Jupyter + Voilà + ipywidgets
- **Data Sources**: Web scraping (BeautifulSoup, requests)

## 📖 Usage

### For Demos and Presentations

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure your environment variables:**
   ```bash
   # Copy the sample environment file
   cp .env.example .env
   
   # Edit .env with your actual Azure OpenAI credentials
   # See .env.example for detailed instructions and all available settings
   ```

3. **Launch the demo:**
   ```bash
   voila demo.ipynb --template=lab
   ```

4. **For showcase room deployment:**
   ```bash
   # Run on specific port for kiosk mode
   voila demo.ipynb --port=8866 --no-browser --template=lab

   # Or use Jupyter Lab for development
   jupyter lab demo.ipynb
   ```

### For Development

Use `main.ipynb` for:
- Building and evaluating the RAG pipeline
- Testing new retrieval strategies
- Running performance benchmarks
- Experimenting with different embeddings

## 📊 Performance

See `artifacts/header_impact_evaluation.json` for detailed metrics showing:
- Improvement percentage from contextual headers
- Baseline vs. enhanced retrieval scores
- Query-level performance breakdown

## 🎨 Customization

### Styling
Edit `voila_config/static/custom.css` to customize:
- Color scheme
- Typography
- Layout and spacing
- Brand elements

### Demo Queries
Add or modify queries in `examples/sample_queries.json` to showcase specific capabilities.

### Data Sources
Add new medical guideline sources by:
1. Adding scraping logic to `rag/scrape.py`
2. Running document ingestion in `main.ipynb`
3. Rebuilding the FAISS index

## 🔐 Security Notes

- Never commit `.env` files with real credentials
- Keep API keys secure when deploying to showcase environments
- Use read-only API keys when possible
- Consider rate limiting for public-facing deployments

## 📝 License

This project is for demonstration and educational purposes. Medical information should be verified with qualified healthcare professionals.

## 🤝 Contributing

For questions, issues, or contributions, please refer to the development notebook (`main.ipynb`) for technical implementation details.

---

**Version**: 1.0.0 (Demo Ready)
**Status**: Production demo deployment
