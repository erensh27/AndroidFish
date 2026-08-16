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

# Ensure ~/.local/bin is in PATH for uv
export PATH="$HOME/.local/bin:$PATH"

# 1. Print ASCII banner
echo "=== Lichess Bot — Moto G32 ==="

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
BOOKS_STATUS="ENABLED"
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

# Check BotLi directory
if [ ! -d "BotLi" ]; then
    echo "Error: BotLi directory not found."
    echo "Please run: bash scripts/setup_termux.sh"
    exit 1
fi

# Pass config into BotLi expected location
cp config.yml BotLi/config.yml

# 15. Start BotLi
echo "Starting BotLi... (Ctrl+C to stop)"

# 16. Run BotLi matchmaking
cd BotLi
exec uv run user_interface.py matchmaking
