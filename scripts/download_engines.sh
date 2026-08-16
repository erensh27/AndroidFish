#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p engines

echo "=== Setting up Stockfish Engine ==="

SYS_ARCH=$(uname -m)
echo "Detected architecture: $SYS_ARCH"

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
        echo "Building armv8 binary with NEON SIMD for Cortex-A53..."
        make -j$(nproc) build ARCH=armv8 COMP=clang \
            CXXFLAGS="-O3 -march=armv8-a+simd -mtune=cortex-a53"
    else
        echo "Building x86-64 binary..."
        make -j$(nproc) build ARCH=x86-64-modern COMP=clang 2>/dev/null \
            || make -j$(nproc) build ARCH=x86-64-modern
    fi
    cp stockfish "$SCRIPT_DIR/engines/stockfish"
    cd "$SCRIPT_DIR"
    rm -rf "$TMP_BUILD"
    chmod +x "$SCRIPT_DIR/engines/stockfish"
}

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

# Verify prebuilt — diagnose before falling back
if [ ! -f "engines/stockfish" ] || ! ./engines/stockfish uci >/dev/null 2>&1; then
    echo "Pre-built binary failed. Diagnosing..."
    ./engines/stockfish uci 2>&1 | head -5 || true
    echo "Falling back to native compilation..."
    build_from_source
fi

# Meaningful performance verification
echo "Verifying Stockfish engine..."
if [ -x "./engines/stockfish" ] && ./engines/stockfish uci >/dev/null 2>&1; then
    echo "Running performance benchmark..."
    SF_NPS=$(./engines/stockfish bench 64 1 13 default depth 2>&1 \
        | grep "Nodes/second" | awk '{print $NF}')
    if [ -n "$SF_NPS" ]; then
        echo "✓ Stockfish verified — ${SF_NPS} nodes/second"
        if [ "$SF_NPS" -lt 500000 ]; then
            echo "⚠ WARNING: NPS is very low. Binary may not be using NEON SIMD."
            echo "  Check: file engines/stockfish"
            echo "  Recompile with CXXFLAGS from FIX.md if needed."
        fi
    else
        echo "✓ Stockfish UCI verified (bench output could not be parsed)"
    fi
else
    echo "Error: Stockfish engine could not be verified."
    exit 1
fi

echo "Engine setup complete!"
