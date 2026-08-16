#!/data/data/com.termux/files/usr/bin/bash
# Run once: bash scripts/setup_termux.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setting up Termux environment for Lichess Bot ==="

# 1. Update packages
if command -v pkg &> /dev/null; then
    echo "Updating Termux packages..."
    pkg update -y && pkg upgrade -y
    # 2. Install dependencies
    echo "Installing Python, Git, Curl, and dependencies..."
    pkg install -y python git curl python-pip clang make
elif command -v apt &> /dev/null; then
    echo "Running on Debian/Ubuntu-based system..."
    apt update -y && apt upgrade -y
    apt install -y python3 git curl python3-pip
fi

# 3. Install uv
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# 4. Add uv to PATH
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

# 5. Clone BotLi into repo root
if [ ! -d "BotLi" ]; then
    echo "Cloning BotLi repository..."
    git clone https://github.com/Torom/BotLi.git
else
    echo "BotLi directory already exists. Skipping clone."
fi

# 6. Install BotLi dependencies using uv
echo "Syncing BotLi dependencies with uv..."
cd BotLi
uv sync
cd ..

# 7. Print completion message
echo "Setup complete. Now run: bash scripts/download_engines.sh"
