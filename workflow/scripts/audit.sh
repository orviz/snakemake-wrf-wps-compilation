#!/usr/bin/bash

set -euo pipefail

# ========================= #
# 1. Parse Input Parameters #
# ========================= #
if [[ $# -ne 7 ]]; then
    echo "Usage: $0 <environment_type> <environment_init_script> <engine_type> <software_name> <software_version> <toolchain_suffix> <output_json>" >&2
    exit 2
fi

ENVIRONMENT_TYPE="$1"
ENVIRONMENT_INIT_SCRIPT="$2"
ENGINE_TYPE="$3"
SOFTWARE_NAME="$4"
SOFTWARE_VERSION="$5"
TOOLCHAIN_SUFFIX="$6"
OUTPUT_JSON="$7"

# ========================================= #
# 2. Initialization of Software Environment #
# ========================================= #
initialize_environment() {
    case "$ENVIRONMENT_TYPE" in
        eessi)
            if [[ -z "$ENVIRONMENT_INIT_SCRIPT" ]]; then
                echo "ERROR: EESSI requires an initialization script." >&2
                return 1
            fi

            if [[ ! -f "$ENVIRONMENT_INIT_SCRIPT" ]]; then
                echo "ERROR: Environment script not found: $ENVIRONMENT_INIT_SCRIPT" >&2
                return 1
            fi

            # EESSI initialization scripts may use unset variables internally.
            set +u
            source "$ENVIRONMENT_INIT_SCRIPT"
            set -u

            if ! command -v module >/dev/null 2>&1; then
                echo "ERROR: 'module' command unavailable after EESSI initialization." >&2
                return 1
            fi

            module load EESSI-extend
            ;;

        custom)
            # A custom environment may optionally provide an initialization script.
            if [[ -n "$ENVIRONMENT_INIT_SCRIPT" ]]; then
                if [[ ! -f "$ENVIRONMENT_INIT_SCRIPT" ]]; then
                    echo "ERROR: Environment script not found: $ENVIRONMENT_INIT_SCRIPT" >&2
                    return 1
                fi

                set +u
                source "$ENVIRONMENT_INIT_SCRIPT"
                set -u
            fi
            ;;

        *)
            echo "ERROR: Unsupported environment: $ENVIRONMENT_TYPE" >&2
            return 1
            ;;
    esac
}

# ======================== #
# 3. Engine-Specific Audit #
# ======================== #
audit_easybuild() {
    if ! command -v eb >/dev/null 2>&1; then
        echo "ERROR: EasyBuild command 'eb' is not available in this environment." >&2
        return 1
    fi

    RECIPE_TARGET="${SOFTWARE_NAME}-${SOFTWARE_VERSION}${TOOLCHAIN_SUFFIX}.eb"

    echo "[Audit] Searching EasyBuild recipes for ${SOFTWARE_NAME} ${SOFTWARE_VERSION}..."

    SEARCH_OUTPUT="$(eb -S "$SOFTWARE_NAME" --detect-loaded-modules=purge 2>&1 || true)"

    if grep -Fq -- "$RECIPE_TARGET" <<< "$SEARCH_OUTPUT"; then
        echo " -> [FOUND] Recipe: $RECIPE_TARGET"
        STATUS="RECIPE_FOUND"
    else
        echo " -> [NOT FOUND] Recipe: $RECIPE_TARGET"
        STATUS="RECIPE_NOT_FOUND"
    fi
}

# ================= #
# 4. Audit Dispatch #
# ================= #
echo "[Audit] Environment=$ENVIRONMENT_TYPE Engine=$ENGINE_TYPE Software=$SOFTWARE_NAME Version=$SOFTWARE_VERSION"

initialize_environment

case "$ENGINE_TYPE" in
    easybuild)
        audit_easybuild
        ;;
    *)
        echo "ERROR: Unsupported installation engine: $ENGINE_TYPE" >&2
        exit 1
        ;;
esac

# ============================= #
# 5. Write JSON Metadata Report #
# ============================= #
mkdir -p "$(dirname "$OUTPUT_JSON")"
cat << EOF > "$OUTPUT_JSON"
{
  "software": "$SOFTWARE_NAME",
  "version": "$SOFTWARE_VERSION",
  "environment": "$ENVIRONMENT_TYPE",
  "engine": "$ENGINE_TYPE",
  "recipe_target": "$TARGET_RECIPE",
  "status": "$STATUS",
  "timestamp": "$(date -Iseconds)"
}
EOF

echo "[Audit] Diagnostic available in $OUTPUT_JSON"
