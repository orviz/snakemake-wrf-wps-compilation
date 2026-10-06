#!/usr/bin/bash

set -euo pipefail

# =========================================================================
# 1. PARSE SNAKEMAKE INPUT PARAMETERS (MARKER_DIR removed)
# =========================================================================
EESSI_INIT_SCRIPT="$1"
STATUS_JSON="$2"
LOCAL_RECIPE_PATH="$3"
SOFTWARE_NAME="$4"
NUM_THREADS="$5"
INSTALL_DIR="$6"

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
# 5. DYNAMIC DISCOVERY AND STANDARD ROOT LINKING (Single Link Abstraction)
# =========================================================================
echo "[Compiler] Scanning for real binary assets within local repo path: $INSTALL_DIR"

if [ "$SOFTWARE_NAME" == "WPS" ]; then
    # 1. Gather the first binary to deduce the deep real root of WPS
    FIRST_BIN=$(find "$INSTALL_DIR" -type f -name "geogrid.exe" | head -n 1)
    if [ -z "$FIRST_BIN" ]; then
        echo "❌ [Error] Sanity Check crashed: geogrid.exe not discovered under $INSTALL_DIR"
        exit 1
    fi
    WPS_REAL_ROOT=$(dirname "$FIRST_BIN")

    # Agrupación robusta usando paréntesis para evitar cortocircuitos extraños en Bash
    if [[ "$WPS_REAL_ROOT" == */geogrid/src ]]; then
        WPS_REAL_ROOT=$(dirname $(dirname "$WPS_REAL_ROOT"))
    elif [[ "$WPS_REAL_ROOT" == */bin ]]; then
        WPS_REAL_ROOT=$(dirname "$WPS_REAL_ROOT")
    fi

    # 2. Remove the empty physical folder to avoid confusion and ensure a single symlink
    rmdir "$INSTALL_DIR" 2>/dev/null || rm -rf "$INSTALL_DIR"

    # 3. Create the single global symlink to the real root
    ln -sfn "$WPS_REAL_ROOT" "$INSTALL_DIR"
    echo " -> [Standardization] Single global symlink created: $INSTALL_DIR -> $WPS_REAL_ROOT"

elif [ "$SOFTWARE_NAME" == "WRF" ]; then
    # 1. Gather the first binary to deduce the deep real root of WRF
    FIRST_BIN=$(find "$INSTALL_DIR" -type f -name "wrf.exe" | head -n 1)
    if [ -z "$FIRST_BIN" ]; then
        echo "❌ [Error] Sanity Check crashed: wrf.exe not discovered under $INSTALL_DIR"
        exit 1
    fi
    WRF_REAL_ROOT=$(dirname "$FIRST_BIN")

    # Agrupación limpia y segura mediante condicionales explícitos
    if [[ "$WRF_REAL_ROOT" == */main ]] || [[ "$WRF_REAL_ROOT" == */run ]] || [[ "$WRF_REAL_ROOT" == */bin ]]; then
        WRF_REAL_ROOT=$(dirname "$WRF_REAL_ROOT")
    fi

    # 2. Remove the empty physical folder to avoid confusion and ensure a single symlink
    rmdir "$INSTALL_DIR" 2>/dev/null || rm -rf "$INSTALL_DIR"

    # 3. Create the single global symlink to the real root
    ln -sfn "$WRF_REAL_ROOT" "$INSTALL_DIR"
    echo " -> [Standardization] Single global symlink created: $INSTALL_DIR -> $WRF_REAL_ROOT"
fi