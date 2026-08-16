#!/usr/bin/env bash
set -e

# Handle exit trap
cleanup() {
    echo ""
    echo "Bot stopped."
}
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure PATH includes local bins
export PATH="$HOME/.local/bin:$PATH"

# 1. Print ASCII banner
echo "=== Lichess Bot — Moto G32 ==="

# 0. Ensure multipart books are reassembled
for part_file in books/*.bin.partaa; do
    if [ -f "$part_file" ]; then
        base_book="${part_file%.partaa}"
        if [ ! -f "$base_book" ]; then
            echo "Assembling opening book: $(basename "$base_book")..."
            cat "${base_book}".part* > "$base_book"
        fi
    fi
done

# 0. Ensure engines/stockfish exists
if [ ! -x "engines/stockfish" ]; then
    echo "Stockfish engine not found. Running download_engines.sh..."
    bash scripts/download_engines.sh
fi

# 0. Ensure BotLi exists
if [ ! -d "BotLi" ]; then
    echo "BotLi directory not found. Automatically cloning BotLi..."
    git clone https://github.com/Torom/BotLi.git
fi

# 0. Ensure required Python dependencies are installed
if ! python3 -c "import psutil" 2>/dev/null; then
    echo "Installing psutil..."
    if command -v pkg &> /dev/null; then
        pkg install -y python-psutil 2>/dev/null || true
    fi
    if ! python3 -c "import psutil" 2>/dev/null; then
        pip install psutil 2>/dev/null || true
    fi
fi

if ! python3 -c "import yaml" 2>/dev/null; then
    echo "Installing PyYAML..."
    if command -v pkg &> /dev/null; then
        pkg install -y libyaml clang make 2>/dev/null || true
    fi
    pip install pyyaml --no-build-isolation 2>/dev/null || pip install pyyaml
fi

if ! python3 -c "import aiohttp" 2>/dev/null; then
    echo "Installing aiohttp in pure-Python mode..."
    AIOHTTP_NO_EXTENSIONS=1 YARL_NO_EXTENSIONS=1 MULTIDICT_NO_EXTENSIONS=1 FROZENLIST_NO_EXTENSIONS=1 pip install aiosignal attrs frozenlist multidict yarl aiohttp
fi

for pkg in chess prompt_toolkit tenacity; do
    if ! python3 -c "import $pkg" 2>/dev/null; then
        echo "Installing ${pkg//_/-}..."
        pip install "${pkg//_/-}"
    fi
done

# 2-5. Validation loops for prompts
while true; do
    printf "Lichess Bot Token: "
    read -r -s TOKEN
    echo ""
    if [ -z "$TOKEN" ]; then
        echo "Error: Token cannot be empty. Please try again."
        continue
    fi
    break
done

while true; do
    printf "Stockfish Threads [recommended: 6]: "
    read -r THREADS_INPUT
    THREADS="${THREADS_INPUT:-6}"
    if [[ "$THREADS" =~ ^[0-9]+$ ]] && [ "$THREADS" -ge 1 ] && [ "$THREADS" -le 8 ]; then
        break
    else
        echo "Error: Threads must be an integer between 1 and 8. Please try again."
    fi
done

while true; do
    printf "Hash size in MB [recommended: 512]: "
    read -r HASH_INPUT
    HASH="${HASH_INPUT:-512}"
    if [[ "$HASH" =~ ^[0-9]+$ ]] && [ "$HASH" -ge 64 ] && [ "$HASH" -le 2048 ]; then
        break
    else
        echo "Error: Hash must be an integer between 64 and 2048 MB. Please try again."
    fi
done

# 6. Copy template to config.yml and substitute placeholders
if [ ! -f "config.yml.template" ]; then
    echo "Error: config.yml.template not found."
    exit 1
fi

cp config.yml.template config.yml
sed -i.bak -e "s|__TOKEN__|$TOKEN|g" -e "s|__THREADS__|$THREADS|g" -e "s|__HASH__|$HASH|g" config.yml
rm -f config.yml.bak

# 7. Check stockfish executable
if [ ! -x "engines/stockfish" ]; then
    echo "Error: engines/stockfish not found or not executable."
    echo "Please run: bash scripts/download_engines.sh"
    exit 1
fi

# 8. Check books directory
BOOK_COUNT=$(find books -maxdepth 1 -name "*.bin" 2>/dev/null | wc -l)
BOOKS_STATUS="ENABLED ($BOOK_COUNT books loaded)"
if [ "$BOOK_COUNT" -eq 0 ]; then
    echo "WARNING: No .bin books found in books/ — book moves will be skipped"
    BOOKS_STATUS="DISABLED"
    python3 -c "
with open('config.yml', 'r') as f:
    content = f.read()
content = content.replace('opening_books:\n  enabled: true', 'opening_books:\n  enabled: false')
with open('config.yml', 'w') as f:
    f.write(content)
" 2>/dev/null || true
fi

# 9. Detect username by calling Lichess API
ACCOUNT_JSON=$(curl -s -H "Authorization: Bearer $TOKEN" https://lichess.org/api/account)
USERNAME=$(echo "$ACCOUNT_JSON" | python3 -c "import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('username', ''))
except Exception:
    print('')
")

if [ -z "$USERNAME" ]; then
    echo "Error: Failed to authenticate with Lichess API using the provided token."
    echo "API Response: $ACCOUNT_JSON"
    exit 1
fi

# 10-14. Status outputs
echo "✓ Logged in as: $USERNAME"
echo "✓ Threads: $THREADS  Hash: ${HASH}MB  Games: 1 at a time"
echo "✓ Accepting: ALL time controls · Standard & Chess960 · rated + casual"
echo "✓ Matchmaking: every 5 minutes"
echo "✓ Online EGTB: DISABLED  |  Local books: $BOOKS_STATUS"

# Pass config into BotLi expected location
cp config.yml BotLi/config.yml

# 15. Start BotLi
echo "Starting BotLi... (Ctrl+C to stop)"

# 16. Run BotLi matchmaking
cd BotLi
if command -v uv &> /dev/null; then
    exec uv run user_interface.py matchmaking
else
    exec python3 user_interface.py matchmaking
fi
