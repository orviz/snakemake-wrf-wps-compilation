# config/profiles/altamira/set-env.sh

if [ -n "${SLURM_JOB_ID:-}" ]; then
    echo "[Altamira Environment] Slurm batch job detected. Purging Lmod & cross-architecture variables..."
    
    # 1. Matar funciones de Lmod de la shell actual
    unset -f module ml 2>/dev/null || true
    
    # 2. Borrar de raíz TODAS las tablas numeradas de Lmod
    unset $(env | grep -E "^_ModuleTable" | cut -d= -f1) || true
    
    # 3. Eliminar contadores, variables de configuración e índices ocultos de Lmod
    unset $(env | grep -E "^__LMOD_" | cut -d= -f1) || true
    unset _LMFILES_ LOADEDMODULES LMOD_VERSION LMOD_CMD LMOD_DIR LMOD_PKG LMOD_ROOT LMOD_RC LMOD_PACKAGE_PATH
    unset LMOD_CONFIG_DIR MODULEPATH MODULESHOME LMOD_SYSTEM_DEFAULT_MODULES
    
    # 4. Eliminar el entorno completo de EESSI/EasyBuild heredado del nodo de login
    unset $(env | grep -E "^EESSI_" | cut -d= -f1) || true
    unset $(env | grep -E "^EASYBUILD_" | cut -d= -f1) || true
    unset __EESSI_VERSION_USED_FOR_INIT
    
    # 5. Forzar comportamiento interactivo limpio para Lmod
    export LMOD_REDIRECT=yes
fi
