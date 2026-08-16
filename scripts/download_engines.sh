#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p engines

echo "=== Setting up Stockfish Engine ==="

SYS_ARCH=$(uname -m)
echo "Detected architecture: $SYS_ARCH"

# Function to build Stockfish from source if prebuilt fails
build_from_source() {
    echo "Compiling Stockfish natively from source for $SYS_ARCH..."
    if command -v pkg &> /dev/null; then
        echo "Installing build tools via pkg..."
        pkg install -y clang make git 2>/dev/null || true
    fi
    TMP_BUILD=$(mktemp -d)
    echo "Cloning official Stockfish repository..."
    git clone --depth 1 https://github.com/official-stockfish/Stockfish.git "$TMP_BUILD/Stockfish"
    cd "$TMP_BUILD/Stockfish/src"
    if [[ "$SYS_ARCH" == "aarch64" || "$SYS_ARCH" == "arm64" ]]; then
        echo "Building armv8 binary with clang..."
        make -j4 build ARCH=armv8 COMP=clang
    else
        echo "Building x86-64 binary..."
        make -j4 build ARCH=x86-64-modern COMP=clang 2>/dev/null || make -j4 build ARCH=x86-64-modern
    fi
    cp stockfish "$SCRIPT_DIR/engines/stockfish"
    cd "$SCRIPT_DIR"
    rm -rf "$TMP_BUILD"
    chmod +x "$SCRIPT_DIR/engines/stockfish"
}

# Try prebuilt first
echo "Downloading Stockfish release..."
if [[ "$SYS_ARCH" == "aarch64" || "$SYS_ARCH" == "arm64" ]]; then
    SF_URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_18/stockfish-android-armv8.tar"
else
    SF_URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_18/stockfish-ubuntu-x86-64-avx2.tar"
fi

TMP_DIR=$(mktemp -d)
if curl -f -sL "$SF_URL" -o "$TMP_DIR/stockfish.tar"; then
    tar -xf "$TMP_DIR/stockfish.tar" -C "$TMP_DIR"
    SF_BIN=$(find "$TMP_DIR" -type f -perm -111 -name "*stockfish*" | head -n 1)
    if [ -z "$SF_BIN" ]; then
        SF_BIN=$(find "$TMP_DIR" -type f -name "*stockfish*" | head -n 1)
    fi
    if [ -n "$SF_BIN" ]; then
        cp "$SF_BIN" engines/stockfish
        chmod +x engines/stockfish
    fi
fi
rm -rf "$TMP_DIR"

# Verify prebuilt binary
if [ ! -f "engines/stockfish" ] || ! ./engines/stockfish uci >/dev/null 2>&1; then
    echo "Pre-built binary not compatible with this environment. Falling back to native compilation..."
    build_from_source
fi

# Final Verification test
echo "Verifying Stockfish engine..."
if [ -x "./engines/stockfish" ] && ./engines/stockfish uci >/dev/null 2>&1; then
    SF_BENCH=$(./engines/stockfish bench 16 1 1 default depth 2>&1 | head -n 1 || true)
    echo "✓ Stockfish test PASS: $SF_BENCH"
else
    echo "Error: Stockfish engine could not be verified."
    exit 1
fi

echo "Engine setup complete!"
