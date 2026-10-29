#!/usr/bin/bash

set -euo pipefail

# ==================================== #
# 1. Parse & Validate Input Parameters #
# ==================================== #
if [[ $# -ne 7 ]]; then
    echo "Usage: $0 <environment_type> <environment_init_script> <engine_type> <status_json> <local_recipe_path> <num_threads> <install_dir>" >&2
    exit 2
fi

ENVIRONMENT_TYPE="$1"
ENVIRONMENT_INIT_SCRIPT="$2"
ENGINE_TYPE="$3"
STATUS_JSON="$4"
LOCAL_RECIPE_PATH="$5"
NUM_THREADS="$6"
INSTALL_DIR="$7"

if [[ ! -f "$STATUS_JSON" ]]; then
    echo "ERROR: Audit report not found: $STATUS_JSON" >&2
    exit 1
fi

if ! [[ "$NUM_THREADS" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: NUM_THREADS must be a positive integer: $NUM_THREADS" >&2
    exit 1
fi

if [[ ! -d "$(dirname "$LOCAL_RECIPE_PATH")" ]]; then
    echo "ERROR: Local recipe directory not found: $(dirname "$LOCAL_RECIPE_PATH")" >&2
    exit 1
fi

# ======================================== #
# 2. Audit Metadata Extraction (from JSON) #
# ======================================== #
STATUS=$(python3 -c "import json; print(json.load(open('$STATUS_JSON'))['status'])")
RECIPE_TARGET=$(python3 -c "import json; print(json.load(open('$STATUS_JSON'))['recipe_target'])")
SOFTWARE_NAME=$(python3 -c "import json; print(json.load(open('$STATUS_JSON'))['software'])")
AUDIT_ENGINE=$(python3 -c "import json; print(json.load(open('$STATUS_JSON'))['engine'])")

if [[ "$AUDIT_ENGINE" != "$ENGINE_TYPE" ]]; then
    echo "ERROR: Engine mismatch. Configured=$ENGINE_TYPE, audited=$AUDIT_ENGINE" >&2
    exit 1
fi

echo "[Compiler] Software=$SOFTWARE_NAME Environment=$ENVIRONMENT_TYPE Engine=$ENGINE_TYPE"
echo "[Compiler] Audit status=$STATUS"

# ================================== #
# 3. Initialize Software Environment #
# ================================== #

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

# ====================================== #
# 4. Engine-Specific Build Configuration #
# ====================================== #

configure_easybuild() {
    if ! command -v eb >/dev/null 2>&1; then
        echo "ERROR: EasyBuild command 'eb' is unavailable." >&2
        return 1
    fi

    export EASYBUILD_PREFIX="$INSTALL_DIR"
    export EASYBUILD_INSTALLPATH="$INSTALL_DIR"

    export EASYBUILD_PARALLEL="$NUM_THREADS"
    export J="$NUM_THREADS"

    # Avoid nested numerical-library parallelism.
    export OPENBLAS_NUM_THREADS=1
    export FLEXIBLAS_NUM_THREADS=1
    export MKL_NUM_THREADS=1

    ulimit -s unlimited
}

# ================= #
# 5. Build Dispatch #
# ================= #

build_easybuild() {
    local recipe_path
    local recipe_args=()

    case "$STATUS" in
        RECIPE_FOUND)
            if [[ -z "$RECIPE_TARGET" ]]; then
                echo "ERROR: Audit reported RECIPE_FOUND without a recipe target." >&2
                return 1
            fi

            recipe_path="$RECIPE_TARGET"

            echo "[Compiler] Using discovered EasyBuild recipe: $recipe_path"
            ;;

        RECIPE_NOT_FOUND)
            if [[ ! -f "$LOCAL_RECIPE_PATH" ]]; then
                echo "ERROR: Recipe not found in repositories and local fallback is missing: $LOCAL_RECIPE_PATH" >&2
                return 1
            fi

            recipe_path="$LOCAL_RECIPE_PATH"

            echo "[Compiler] Using local fallback recipe: $recipe_path"

            # Local recipe-specific options.
            recipe_args+=(
                "--ignore-checksums"
                "--patches-path=$(dirname "$LOCAL_RECIPE_PATH")"
            )
            ;;

        *)
            echo "ERROR: Unsupported audit status: $STATUS" >&2
            return 1
            ;;
    esac

    eb "$recipe_path" \
        --robot \
        --parallel="$NUM_THREADS" \
        --local-var-naming-check=warn \
        --skip-test-step \
        --detect-loaded-modules=purge \
        "${recipe_args[@]}" \
        --rebuild \
        --force
}

# ================= #
# 6. Execution Flow #
# ================= #

initialize_environment

case "$ENGINE_TYPE" in
    easybuild)
        configure_easybuild
        build_easybuild
        ;;

    *)
        echo "ERROR: Unsupported installation engine: $ENGINE_TYPE" >&2
        exit 1
        ;;
esac

echo "[Compiler] Build completed for $SOFTWARE_NAME"