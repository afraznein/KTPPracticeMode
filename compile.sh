#!/bin/bash
# KTPPracticeMode Plugin Compiler - WSL/Linux version
#
# Test-mode build (Tier 2 integration tests):
#   KTP_TEST_MODE=1 bash compile.sh
#   → output: compiled/test/KTPPracticeMode.amxx (NOT staged to production)

set -e  # Exit on error

# Empty string = production build; "1" = test-mode build.
TEST_MODE="${KTP_TEST_MODE:-}"

echo "========================================"
if [ "$TEST_MODE" = "1" ]; then
    echo "KTPPracticeMode Plugin Compiler (TEST-MODE)"
else
    echo "KTPPracticeMode Plugin Compiler (WSL)"
fi
echo "========================================"
echo

# ============================================
# Path Configuration
# ============================================

KTPAMXX_DIR="/mnt/n/Nein_/KTP Git Projects/KTPAMXX"
KTPAMXX_BUILD="$KTPAMXX_DIR/obj-linux/packages/base/addons/ktpamx/scripting"
KTPAMXX_INCLUDES="$KTPAMXX_DIR/plugins/include"

# Handle both direct execution and piped execution
if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="/mnt/n/Nein_/KTP Git Projects/KTPPracticeMode"
fi
PLUGIN_NAME="KTPPracticeMode"
if [ "$TEST_MODE" = "1" ]; then
    OUTPUT_DIR="$SCRIPT_DIR/compiled/test"
else
    OUTPUT_DIR="$SCRIPT_DIR/compiled"
fi
STAGE_DIR="/mnt/n/Nein_/KTP Git Projects/KTP DoD Server/serverfiles/dod/addons/ktpamx/plugins"

TEMP_BUILD="/tmp/ktpbuild_practice"

# ============================================
# Validation
# ============================================

if [ ! -f "$KTPAMXX_BUILD/amxxpc" ]; then
    echo "[ERROR] KTPAMXX Linux compiler not found!"
    echo "        Expected: $KTPAMXX_BUILD/amxxpc"
    echo "        Please build KTPAMXX first: cd KTPAMXX && ./build_linux.sh"
    exit 1
fi

if [ ! -f "$KTPAMXX_INCLUDES/amxmodx.inc" ]; then
    echo "[ERROR] KTPAMXX includes not found!"
    echo "        Expected: $KTPAMXX_INCLUDES"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/$PLUGIN_NAME.sma" ]; then
    echo "[ERROR] Source file not found: $PLUGIN_NAME.sma"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ============================================
# Compile
# ============================================

echo "[INFO] Compiling $PLUGIN_NAME.sma..."
echo "       Compiler: $KTPAMXX_BUILD/amxxpc"
echo "       Includes: $KTPAMXX_INCLUDES"
echo

# Create fresh temp build directory (remove stale includes)
rm -rf "$TEMP_BUILD"
mkdir -p "$TEMP_BUILD"

# Copy compiler and libraries
cp "$KTPAMXX_BUILD/amxxpc" "$TEMP_BUILD/"
cp "$KTPAMXX_BUILD/amxxpc32.so" "$TEMP_BUILD/"
cp -r "$KTPAMXX_INCLUDES" "$TEMP_BUILD/include"

# Generate build_info.inc for ktp_version_reporter — git SHA + build time
# get baked into the .amxx so `amx_ktp_versions` rcon can report what's
# actually deployed. Falls back to "unknown" off-toolchain.
GIT_SHA=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_DIRTY=""
if [ "$GIT_SHA" != "unknown" ]; then
    if ! git -C "$SCRIPT_DIR" diff --quiet 2>/dev/null || \
       ! git -C "$SCRIPT_DIR" diff --cached --quiet 2>/dev/null; then
        GIT_DIRTY="-dirty"
    fi
fi
BUILD_TIME=$(date -u +%Y-%m-%dT%H:%MZ)
cat > "$TEMP_BUILD/include/build_info.inc" <<EOF
#define KTP_BUILD_SHA "${GIT_SHA}${GIT_DIRTY}"
#define KTP_BUILD_TIME "$BUILD_TIME"
EOF
echo "[INFO] build_info: SHA=${GIT_SHA}${GIT_DIRTY} BUILD_TIME=$BUILD_TIME"

# Convert line endings and copy source
sed 's/\r$//' "$SCRIPT_DIR/$PLUGIN_NAME.sma" > "$TEMP_BUILD/$PLUGIN_NAME.sma"

# Compile. amxxpc accepts trailing positional NAME=VALUE args as injected
# `#define`s; KTP_TEST_MODE=1 enables the test-mode block in the .sma.
cd "$TEMP_BUILD"
if [ "$TEST_MODE" = "1" ]; then
    echo "[INFO] Building with -DKTP_TEST_MODE — adds amx_ktp_prac_test_enable (ADMIN_RCON, cmd_access-gated) + entry diagnostics"
    ./amxxpc "$PLUGIN_NAME.sma" -i./include -o"$PLUGIN_NAME.amxx" KTP_TEST_MODE=1
else
    ./amxxpc "$PLUGIN_NAME.sma" -i./include -o"$PLUGIN_NAME.amxx"
fi

if [ $? -ne 0 ]; then
    echo
    echo "========================================"
    echo "[FAILED] Compilation failed!"
    echo "========================================"
    exit 1
fi

# Copy output
cp "$PLUGIN_NAME.amxx" "$OUTPUT_DIR/"

echo
echo "========================================"
echo "[SUCCESS] Compilation successful!"
echo "========================================"
echo "Output: $OUTPUT_DIR/$PLUGIN_NAME.amxx"
echo

# ============================================
# Stage to Server
# ============================================

if [ "$TEST_MODE" = "1" ]; then
    echo "[INFO] Test-mode build — NOT staged to production serverfiles."
    echo "       Stage manually to the Tier 2 runner tree."
elif [ ! -d "$STAGE_DIR" ]; then
    echo "[WARN] Stage directory does not exist: $STAGE_DIR"
    echo "       Skipping staging."
else
    echo "[INFO] Staging to server..."
    cp "$OUTPUT_DIR/$PLUGIN_NAME.amxx" "$STAGE_DIR/$PLUGIN_NAME.amxx"
    echo "[OK] Staged: $STAGE_DIR/$PLUGIN_NAME.amxx"
fi

echo
echo "Done!"
