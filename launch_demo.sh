#!/bin/bash
# Launch script for Medical RAG Demo

set -e

echo "🏥 Medical Context Retrieval Demo Launcher"
echo "=========================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create your environment configuration:"
    echo ""
    echo "  cp .env.example .env"
    echo ""
    echo "Then edit .env with your Azure OpenAI credentials."
    echo "See .env.example for detailed setup instructions."
    echo ""
    exit 1
fi

# Check if virtual environment is activated
if [ -z "$VIRTUAL_ENV" ]; then
    echo "⚠️  Warning: No virtual environment detected"
    echo "Consider activating your virtual environment first:"
    echo "  source .venv/bin/activate"
    echo ""
fi

# Check if dependencies are installed
if ! python -c "import voila" 2>/dev/null; then
    echo "📦 Installing dependencies..."
    pip install -q -r requirements.txt
    echo "✅ Dependencies installed"
    echo ""
fi

# Check if cache exists
if [ ! -d cache ] || [ -z "$(ls -A cache)" ]; then
    echo "⚠️  Warning: No cached data found"
    echo "The demo will need to build the index on first run (may take several minutes)"
    echo ""
fi

# Launch Voilà
echo "🚀 Launching demo..."
echo ""
echo "Demo will open at: http://localhost:8866"
echo "Press Ctrl+C to stop the server"
echo ""
echo "----------------------------------------"

# Multi-user/"stateless" friendly kernel config (prevents IPython history sqlite locks)
export JUPYTER_CONFIG_DIR="${JUPYTER_CONFIG_DIR:-$(pwd)/jupyter_config}"

voila demo.ipynb \
    --port=8866 \
    --template=lab \
    --VoilaConfiguration.file_allowlist="['.*']" \
    --no-browser

echo ""
echo "Demo stopped."
