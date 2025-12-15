#!/bin/bash

# Medical RAG System - Admin Panel Launcher
# Starts the Voilà admin interface for system management

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Medical RAG Admin Panel${NC}"
echo "============================"
echo ""

# Check if virtual environment exists
if [ ! -d ".venv" ]; then
    echo -e "${YELLOW}⚠️  Virtual environment not found. Creating...${NC}"
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
else
    source .venv/bin/activate
fi

# Check if admin.ipynb exists
if [ ! -f "admin.ipynb" ]; then
    echo -e "${YELLOW}❌ admin.ipynb not found!${NC}"
    exit 1
fi

# Set port
ADMIN_PORT="${ADMIN_PORT:-8867}"

echo -e "${GREEN}🚀 Starting admin panel...${NC}"
echo ""
echo -e "${YELLOW}📋 Admin Interface:${NC} http://localhost:${ADMIN_PORT}"
echo -e "${YELLOW}🔐 Access Control:${NC} Restrict access to authorized administrators only"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""

# Multi-user/"stateless" friendly kernel config (prevents IPython history sqlite locks)
export JUPYTER_CONFIG_DIR="${JUPYTER_CONFIG_DIR:-$(pwd)/jupyter_config}"

# Launch Voilà with admin notebook
voila admin.ipynb \
    --port=${ADMIN_PORT} \
    --no-browser \
    --Voila.ip=0.0.0.0 \
    --VoilaConfiguration.file_allowlist=['.*'] \
    --VoilaConfiguration.show_tracebacks=True \
    --enable_nbextensions=True
