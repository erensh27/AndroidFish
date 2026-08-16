#!/data/data/com.termux/files/usr/bin/bash
# Run once: bash scripts/setup_termux.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setting up Termux environment for Lichess Bot ==="

# 1. Update packages and install Termux build tools & packages
if command -v pkg &> /dev/null; then
    echo "Updating Termux packages..."
    pkg update -y && pkg upgrade -y
    echo "Installing Python, Git, Curl, Pip, build tools, libyaml, and python-psutil..."
    pkg install -y python git curl python-pip clang make libyaml python-psutil
elif command -v apt &> /dev/null; then
    echo "Running on Debian/Ubuntu-based system..."
    apt update -y && apt upgrade -y
    apt install -y python3 git curl python3-pip libyaml-dev python3-psutil 2>/dev/null || apt install -y python3 git curl python3-pip
fi

# 2. Assemble any multipart opening books
for part_file in books/*.bin.partaa; do
    if [ -f "$part_file" ]; then
        base_book="${part_file%.partaa}"
        if [ ! -f "$base_book" ]; then
            echo "Assembling opening book: $(basename "$base_book")..."
            cat "${base_book}".part* > "$base_book"
        fi
    fi
done

# 3. Clone BotLi into repo root
if [ ! -d "BotLi" ]; then
    echo "Cloning BotLi repository..."
    git clone https://github.com/Torom/BotLi.git
else
    echo "BotLi directory already exists. Skipping clone."
fi

# 4. Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip 2>/dev/null || true
pip install chess prompt-toolkit tenacity
pip install pyyaml --no-build-isolation 2>/dev/null || pip install pyyaml

if ! python3 -c "import aiohttp" 2>/dev/null; then
    echo "Installing aiohttp in pure-Python mode..."
    AIOHTTP_NO_EXTENSIONS=1 YARL_NO_EXTENSIONS=1 MULTIDICT_NO_EXTENSIONS=1 FROZENLIST_NO_EXTENSIONS=1 pip install aiosignal attrs frozenlist multidict yarl aiohttp
fi

# 5. Print completion message
echo "Setup complete. Now run: bash scripts/download_engines.sh"
