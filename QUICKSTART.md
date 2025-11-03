# Quick Start Guide

## � Prerequisites

### Configure Environment Variables
```bash
# Copy the sample environment file
cp .env.example .env

# Edit .env with your Azure OpenAI credentials
# - AZURE_OPENAI_ENDPOINT (Required: your Azure OpenAI service URL)
# - AZURE_OPENAI_API_KEY (Required: your API key)
# - AOAI_EMBED_MODEL (if you want to change your embedding model deployment name)
# - AOAI_CHAT_MODEL (if you want to change your chat model deployment name)
```

**📝 Get Azure OpenAI credentials**: See `.env.example` for detailed setup instructions.

---

## �🚀 Launch Demo in 3 Steps

### Step 1: Verify Setup
```bash
./verify_setup.sh
```

### Step 2: Install Dependencies (if needed)
```bash
pip install -r requirements.txt
```

### Step 3: Launch Demo
```bash
./launch_demo.sh
```

**Demo URL**: http://localhost:8866

---

## 📚 Documentation

| File | Purpose |
|------|---------|
| `QUICKSTART.md` | ← You are here (fastest path to demo) |
| `DEMO_GUIDE.md` | Complete showcase room guide with demo script |
| `CLEANUP_SUMMARY.md` | What was changed and why |
| `README.md` | Full project documentation |

---

## 🎯 Demo Files

| File | Purpose |
|------|---------|
| `demo.ipynb` | Customer-facing interactive demo |
| `main.ipynb` | Development/technical notebook |
| `launch_demo.sh` | One-command launcher |
| `verify_setup.sh` | Setup validation |

---

## ⚡ One-Line Commands

**Launch demo:**
```bash
./launch_demo.sh
```

**Launch on different port:**
```bash
voila demo.ipynb --port=8877 --template=lab
```

**Launch in Jupyter (for editing):**
```bash
jupyter notebook demo.ipynb
```

**Check status:**
```bash
./verify_setup.sh
```

---

## 🎬 5-Minute Demo Script

1. Open demo at http://localhost:8866
2. Click "Example 1" (breast cancer screening)
3. Click "Search Guidelines"
4. Show results with confidence scores
5. Try "Example 2" (lymphoma treatment)
6. Scroll to performance metrics
7. Done!

**Full script**: See `DEMO_GUIDE.md`

---

## ❓ Quick Troubleshooting

**Demo won't start?**
```bash
./verify_setup.sh  # Check what's missing
pip install -r requirements.txt  # Install dependencies
```

**Port already in use?**
```bash
voila demo.ipynb --port=8877 --template=lab
```

**Results not showing?**
- Check `.env` has Azure OpenAI credentials
- Verify cache folder has files
- Check terminal for error messages

---

## 🎨 Quick Customization

**Add your logo:**
Edit `voila_config/static/custom.css`

**Change colors:**
Edit CSS variables in `custom.css`

**Add example queries:**
Edit `examples/sample_queries.json`

---

**Need more help?** See `DEMO_GUIDE.md`
