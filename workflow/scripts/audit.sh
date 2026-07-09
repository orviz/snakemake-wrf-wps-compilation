#!/usr/bin/bash
# workflow/scripts/audit.sh
set -euo pipefail

# =========================================================================
# 1. PARSE SNAKEMAKE INPUT PARAMETERS
# =========================================================================
EESSI_INIT_SCRIPT="$1"
SOFTWARE_NAME="$2"
SOFTWARE_VERSION="$3"
TOOLCHAIN_SUFIX="$4"
OUTPUT_JSON="$5"

# =========================================================================
# 2. STERILE AND SAFE INITIALIZATION OF THE EESSI STACK
# =========================================================================
set +u
source "$EESSI_INIT_SCRIPT"
module load EESSI-extend
set -u

echo "[Auditor EESSI] Interrogating central infrastructure for $SOFTWARE_NAME v$SOFTWARE_VERSION..."

TARGET_RECIPE="${SOFTWARE_NAME}-${SOFTWARE_VERSION}${TOOLCHAIN_SUFIX}.eb"

# Capture & analyze 'eb -S' output
EB_SEARCH_OUT=$(eb -S "$SOFTWARE_NAME" --detect-loaded-modules=purge 2>&1 || true)

# =========================================================================
# 3. EMPIRICAL ANALYSIS OF CVMFS INDEX
# =========================================================================
if echo "$EB_SEARCH_OUT" | grep -q "$TARGET_RECIPE"; then
    echo " -> [FOUND] Oficial EasyBuild recipe '$TARGET_RECIPE' available in EESSI."
    STATUS="EESSI_OFFICIAL"
else
    echo " -> [NOT FOUND] Official EasyBuild recipe '$TARGET_RECIPE' NOT available in EESSI. Fallback to local."
    STATUS="FALLBACK_LOCAL"
fi

# =========================================================================
# 4. WRITE STRUCTURED JSON METADATA FOOTPRINT
# =========================================================================
mkdir -p "$(dirname "$OUTPUT_JSON")"
cat << EOF > "$OUTPUT_JSON"
{
  "software": "$SOFTWARE_NAME",
  "version": "$SOFTWARE_VERSION",
  "recipe_target": "$TARGET_RECIPE",
  "status": "$STATUS",
  "timestamp": "$(date -Iseconds)"
}
EOF

echo "[EESSI Audit] Diagnostic available in $OUTPUT_JSON"
