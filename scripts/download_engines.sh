#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p engines

echo "=== Downloading Chess Engines and NNUE Evaluation Files ==="

# 1. Download Stockfish for Android ARM64
echo "Checking latest Stockfish for Android ARM64..."
SF_URL=$(curl -s https://api.github.com/repos/official-stockfish/Stockfish/releases/latest | \
    python3 -c "import sys, json
try:
    assets = json.load(sys.stdin).get('assets', [])
    for a in assets:
        name = a.get('name', '')
        if 'android-armv8.tar' in name or ('android' in name and 'arm64' in name):
            print(a.get('browser_download_url', ''))
            break
except Exception:
    pass
")

if [ -z "$SF_URL" ]; then
    echo "Falling back to known Stockfish ARM64 release URL..."
    SF_URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_18/stockfish-android-armv8.tar"
fi

echo "Downloading Stockfish from: $SF_URL"
TMP_DIR=$(mktemp -d)
if ! curl -f -sL "$SF_URL" -o "$TMP_DIR/stockfish.tar"; then
    echo "Error: Failed to download Stockfish from $SF_URL"
    rm -rf "$TMP_DIR"
    exit 1
fi

tar -xf "$TMP_DIR/stockfish.tar" -C "$TMP_DIR"
SF_BIN=$(find "$TMP_DIR" -type f -name "*stockfish*" | head -n 1)
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

# 2. Download or Build Fairy-Stockfish for Android ARM64
echo "Checking Fairy-Stockfish for Android ARM64..."
FAIRY_URL=$(curl -s https://api.github.com/repos/fairy-stockfish/Fairy-Stockfish/releases/latest | \
    python3 -c "import sys, json
try:
    assets = json.load(sys.stdin).get('assets', [])
    for a in assets:
        name = a.get('name', '')
        if ('android' in name or 'linux' in name) and ('arm64' in name or 'armv8' in name or 'aarch64' in name):
            print(a.get('browser_download_url', ''))
            break
except Exception:
    pass
")

if [ -n "$FAIRY_URL" ]; then
    echo "Downloading Fairy-Stockfish from: $FAIRY_URL"
    if ! curl -f -sL "$FAIRY_URL" -o engines/fairy-stockfish; then
        echo "Error: Failed to download Fairy-Stockfish from $FAIRY_URL"
        exit 1
    fi
    chmod +x engines/fairy-stockfish
    echo "✓ Fairy-Stockfish downloaded to engines/fairy-stockfish"
else
    echo "No prebuilt Fairy-Stockfish ARM64 release asset found. Building from source for ARMv8..."
    BUILD_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/fairy-stockfish/Fairy-Stockfish.git "$BUILD_DIR/Fairy-Stockfish"
    make -C "$BUILD_DIR/Fairy-Stockfish/src" -j"$(nproc 2>/dev/null || echo 2)" ARCH=armv8
    cp "$BUILD_DIR/Fairy-Stockfish/src/fairy-stockfish" engines/fairy-stockfish
    chmod +x engines/fairy-stockfish
    rm -rf "$BUILD_DIR"
    echo "✓ Fairy-Stockfish built and installed to engines/fairy-stockfish"
fi

# 3. Download Fairy-Stockfish NNUEs
echo "Downloading variant NNUE files into engines/..."
NNUE_FILES=(
    "3check-cb5f517c228b.nnue:1z5oUQbqiE0ZIoQ8Z64y2lF91Rz1rUoWP"
    "antichess-dd3cbe53cd4e.nnue:1a6j61utWpCTADQ8k6BBqYMcKjJ5ESdbl"
    "atomic-2cf13ff256cc.nnue:1bC7T3iDft8Kbuxlu3Vm2fERxk7cOSoDy"
    "crazyhouse-8ebf84784ad2.nnue:1nieguR4yCb0BlME-AUhcrFYkmyIOGvqs"
    "horde-28173ddccabe.nnue:16BQztGqFIS1n_dYtmdfFVE2EexF-KagX"
    "kingofthehill-978b86d0e6a4.nnue:1x25r_1PgB5XqttkfR494M4rseiIm0BAV"
    "racingkings-636b95f085e3.nnue:1Tiq8FqSu7eiekE2iaWQzSdJPg-mhvLzJ"
)

BASE_RELEASE_URL="https://github.com/fairy-stockfish/Fairy-Stockfish/releases/download/fairy_sf_14"

for ENTRY in "${NNUE_FILES[@]}"; do
    FILE_NAME="${ENTRY%%:*}"
    GDRIVE_ID="${ENTRY##*:}"
    TARGET_PATH="engines/$FILE_NAME"

    if [ -f "$TARGET_PATH" ]; then
        echo "  - $FILE_NAME already exists, skipping."
        continue
    fi

    echo "  - Downloading $FILE_NAME..."
    GITHUB_URL="$BASE_RELEASE_URL/$FILE_NAME"
    if curl -f -sL "$GITHUB_URL" -o "$TARGET_PATH" 2>/dev/null; then
        echo "    ✓ Downloaded from GitHub releases"
    else
        GDRIVE_URL="https://drive.usercontent.google.com/download?id=$GDRIVE_ID&export=download"
        if curl -f -sL "$GDRIVE_URL" -o "$TARGET_PATH" 2>/dev/null; then
            echo "    ✓ Downloaded from official repository"
        else
            echo "Warning: Could not download $FILE_NAME. You can manually download it to engines/"
        fi
    fi
done

# 4. Engine verification tests
echo "Verifying engines..."
ARCH=$(uname -m)

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    # Test Stockfish
    if [ -x "./engines/stockfish" ]; then
        SF_BENCH=$(./engines/stockfish bench 16 1 1 default depth 2>&1 | head -n 1 || true)
        if [ -n "$SF_BENCH" ]; then
            echo "✓ Stockfish test PASS: $SF_BENCH"
        else
            echo "Engine test FAILED — Stockfish binary may be wrong arch"
            exit 1
        fi
    fi

    # Test Fairy-Stockfish
    if [ -x "./engines/fairy-stockfish" ]; then
        FAIRY_UCI=$(printf "uci\nquit\n" | ./engines/fairy-stockfish 2>&1 || true)
        if echo "$FAIRY_UCI" | grep -q "uciok"; then
            echo "✓ Fairy-Stockfish UCI handshake test PASS"
        else
            echo "Engine test FAILED — Fairy-Stockfish binary may be wrong arch"
            exit 1
        fi
    fi
else
    echo "Note: Host architecture ($ARCH) is not aarch64. Skipping local binary execution check (binaries are prepared for Android ARM64)."
fi

echo "Engine setup complete!"
