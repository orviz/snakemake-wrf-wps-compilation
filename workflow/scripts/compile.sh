#!/usr/bin/bash

set -euo pipefail

# =========================================================================
# 1. PARSE SNAKEMAKE INPUT PARAMETERS
# =========================================================================
EESSI_INIT_SCRIPT="$1"
STATUS_JSON="$2"
LOCAL_RECIPE_PATH="$3"
MARKER_DIR="$4"
SOFTWARE_NAME="$5"
NUM_THREADS="$6"
INSTALL_DIR="$7"

# =========================================================================
# 2. DYNAMIC METADATA EXTRACTION FROM JSON (HPC-Safe using Python)
# =========================================================================
STATUS=$(python3 -c "import json; print(json.load(open('$STATUS_JSON'))['status'])")
RECIPE_TARGET=$(python3 -c "import json; print(json.load(open('$STATUS_JSON'))['recipe_target'])")
SOFTWARE_NAME=$(python3 -c "import json; print(json.load(open('$STATUS_JSON'))['software'])")

# =========================================================================
# 3. ISOLATED AND STERILE INITIALIZATION OF THE EESSI STACK
# =========================================================================
set +u
source "$EESSI_INIT_SCRIPT"
module load EESSI-extend
set -u

# Force EasyBuild to use INSTALL_DIR
export EASYBUILD_PREFIX="$INSTALL_DIR"
export EASYBUILD_INSTALLPATH="$INSTALL_DIR"

# Core threading and memory mitigation flags for subprocess scheduling
export EASYBUILD_PARALLEL="$NUM_THREADS"
export OPENBLAS_NUM_THREADS=1
export FLEXIBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
ulimit -s unlimited

# =========================================================================
# 4. ALGORITHMIC BUILD DECISION (Bypassing EESSI Hooks Restriction)
# =========================================================================
if [ "$STATUS" == "EESSI_OFFICIAL" ]; then
    echo "[Compiler] Tuning to OFFICIAL mode. Using EESSI native recipe: $RECIPE_TARGET"

    eb "$RECIPE_TARGET" \
      --robot \
      --parallel="$NUM_THREADS" \
      --local-var-naming-check=warn \
      --skip-test-step \
      --detect-loaded-modules=purge \
      --rebuild \
      --force
else
    echo "[Compiler] Tuning to LOCAL FALLBACK mode. Injecting custom recipe and patches..."
    PATCH_DIR=$(dirname "$LOCAL_RECIPE_PATH")

    eb "$LOCAL_RECIPE_PATH" \
      --robot \
      --parallel="$NUM_THREADS" \
      --local-var-naming-check=warn \
      --skip-test-step \
      --detect-loaded-modules=purge \
      --ignore-checksums \
      --rebuild \
      --patches-path="$PATCH_DIR" \
      --force
fi

# =========================================================================
# 5. DYNAMIC DISCOVERY AND MULTI-BINARY LINKING
# =========================================================================
echo "[Compiler] Scanning for real binary assets within local repo path: $INSTALL_DIR"
mkdir -p "$MARKER_DIR"

if [ "$SOFTWARE_NAME" == "WPS" ]; then
    # Seek and link the 3 WPS binaries (geogrid, ungrib, metgrid)
    for bin in geogrid ungrib metgrid; do
        REAL_BIN=$(find "$INSTALL_DIR" -type f -name "${bin}.exe" | head -n 1)
        if [ -n "$REAL_BIN" ]; then
            echo " -> [OK] WPS binary located at: $REAL_BIN"
            ln -sf "$REAL_BIN" "$MARKER_DIR/${bin}.exe"
        else
            echo "❌ [Error] Sanity Check crashed: ${bin}.exe not discovered in $INSTALL_DIR"
            exit 1
        fi
    done
elif [ "$SOFTWARE_NAME" == "WRF" ]; then
    # Seek and link the 2 WRF binaries (real, wrf)
    for bin in real wrf; do
        REAL_BIN=$(find "$INSTALL_DIR" -type f -name "${bin}.exe" | head -n 1)
        if [ -n "$REAL_BIN" ]; then
            echo " -> [OK] WRF binary located at: $REAL_BIN"
            ln -sf "$REAL_BIN" "$MARKER_DIR/${bin}.exe"
        else
            echo "❌ [Error] Sanity Check crashed: ${bin}.exe not discovered in $INSTALL_DIR"
            exit 1
        fi
    done
else
    echo "❌ [Error] Unknown software target: $SOFTWARE_NAME"
    exit 1
fi

echo "[Compiler Success] All production symlinks successfully established in: $MARKER_DIR"