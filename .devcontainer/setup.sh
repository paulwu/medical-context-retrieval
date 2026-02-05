#!/bin/bash
set -e

echo "Starting devcontainer setup..."

# Install Python requirements
if [ -f "requirements.txt" ]; then
    echo "Installing requirements from requirements.txt..."
    pip install --no-cache-dir -r requirements.txt
else
    echo "requirements.txt not found!"
fi

# Install/Update Jupyter tools
echo "Installing/Updating Jupyter kernel..."
pip install --upgrade ipykernel jupyter notebook
python -m ipykernel install --user --name python3 --display-name 'Python 3'

# Fix substitutions and permissions for scripts
echo "Fixing script line endings and permissions..."
chmod +x *.sh
# Handle line endings via sed if dos2unix is missing
if command -v dos2unix &> /dev/null; then
    dos2unix *.sh
else
    # Remove CR from CRLF (if any)
    sed -i 's/\r$//' *.sh
fi

# Create cache directory
echo "Creating cache directory..."
mkdir -p cache

# Configure git defaults
echo "Configuring git defaults..."
git config --global pull.rebase true

echo "Setup complete."
