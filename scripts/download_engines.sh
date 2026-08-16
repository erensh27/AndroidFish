#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p engines

echo "=== Downloading Stockfish Engine ==="

SYS_ARCH=$(uname -m)
echo "Detected architecture: $SYS_ARCH"

# Download Stockfish
echo "Checking Stockfish release..."
if [[ "$SYS_ARCH" == "aarch64" || "$SYS_ARCH" == "arm64" ]]; then
    SF_URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_18/stockfish-android-armv8.tar"
    # Try getting latest if available
    LATEST_URL=$(curl -s https://api.github.com/repos/official-stockfish/Stockfish/releases/latest | \
        python3 -c "import sys, json
try:
    assets = json.load(sys.stdin).get('assets', [])
    for a in assets:
        name = a.get('name', '')
        if 'android-armv8.tar' in name:
            print(a.get('browser_download_url', ''))
            break
except Exception:
    pass
" 2>/dev/null || true)
    [ -n "$LATEST_URL" ] && SF_URL="$LATEST_URL"
else
    # For x86_64 or PC testing
    SF_URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_18/stockfish-ubuntu-x86-64-avx2.tar"
    LATEST_URL=$(curl -s https://api.github.com/repos/official-stockfish/Stockfish/releases/latest | \
        python3 -c "import sys, json
try:
    assets = json.load(sys.stdin).get('assets', [])
    for a in assets:
        name = a.get('name', '')
        if 'ubuntu-x86-64' in name and name.endswith('.tar'):
            print(a.get('browser_download_url', ''))
            break
except Exception:
    pass
" 2>/dev/null || true)
    [ -n "$LATEST_URL" ] && SF_URL="$LATEST_URL"
fi

echo "Downloading Stockfish from: $SF_URL"
TMP_DIR=$(mktemp -d)
if ! curl -f -sL "$SF_URL" -o "$TMP_DIR/stockfish.tar"; then
    echo "Error: Failed to download Stockfish from $SF_URL"
    rm -rf "$TMP_DIR"
    exit 1
fi

tar -xf "$TMP_DIR/stockfish.tar" -C "$TMP_DIR"
SF_BIN=$(find "$TMP_DIR" -type f -perm -111 -name "*stockfish*" | head -n 1)
if [ -z "$SF_BIN" ]; then
    SF_BIN=$(find "$TMP_DIR" -type f -name "*stockfish*" | head -n 1)
fi

if [ -n "$SF_BIN" ]; then
    cp "$SF_BIN" engines/stockfish
    chmod +x engines/stockfish
    echo "✓ Stockfish installed to engines/stockfish"
else
    echo "Error: Could not extract stockfish binary from archive."
    rm -rf "$TMP_DIR"
    exit 1
fi
rm -rf "$TMP_DIR"

# Verification test
echo "Verifying Stockfish engine..."
if [ -x "./engines/stockfish" ]; then
    SF_BENCH=$(./engines/stockfish bench 16 1 1 default depth 2>&1 | head -n 1 || true)
    if [ -n "$SF_BENCH" ]; then
        echo "✓ Stockfish test PASS: $SF_BENCH"
    else
        echo "Note: Stockfish binary not executable directly on this host arch (expected if cross-downloaded for Android ARM64)."
    fi
fi

echo "Engine setup complete!"
