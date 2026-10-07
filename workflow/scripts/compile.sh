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
export J="$NUM_THREADS"
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

echo "[Compiler Success] EasyBuild packaging process completed for: $SOFTWARE_NAME"