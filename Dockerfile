# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir notebook ipykernel nbconvert \
    && python -m ipykernel install --sys-prefix

# Copy application code
COPY rag/ ./rag/
COPY cache/ ./cache/
COPY voila_config/ ./voila_config/
COPY demo.ipynb .

# Create necessary directories
RUN mkdir -p data_pilot/pdfs artifacts \
    && python -m jupyter trust demo.ipynb

# Expose port for Voilà
EXPOSE 8866

# Set environment variables
ENV VOILA_PORT=8866
ENV VOILA_IP=0.0.0.0
ENV VOILA_CONFIG_PATH=/app/voila_config

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8866/ || exit 1

# Run Voilà
CMD ["voila", "demo.ipynb", "--config=/app/voila_config/voila.json", "--port=8866", "--no-browser", "--Voila.ip=0.0.0.0"]
