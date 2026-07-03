# WRF & WPS Automated Deployment over EESSI with Snakemake

This repository provides a **Snakemake** workflow designed to compile both the **Weather Research and Forecasting (WRF) Model** and the **WRF Pre-processing System (WPS)** directly on top of the **EESSI (European Environment for Scientific Software Installations)** shared stack via CVMFS.

By leveraging optimized host-injection toolchains (such as foss/2024a), this workflow dynamically audits the centralized EESSI environment to determine whether to utilize official distributed EasyConfigs or seamlessly inject local fallbacks.

---

## Environment Architecture

This project relies on **Pixi** to deploy an isolated, project-confined execution environment containing Python 3, Snakemake 8+, and the Snakemake native Slurm cluster submission plugins.

### 1. Install Pixi (One-time setup per user)
If Pixi is not yet available on your cluster login node, run the following standalone script:
```bash
curl -fsSL https://pixi.sh/install.sh | sh
source ~/.bashrc
```

### 2. Clone this repository

Clone this project into your scratch or home space inside the cluster:

```bash
git clone https://github.com/orviz/snakemake-wps-eessi
cd snakemake-wps-eessi
```

### 3. Workspace Initialization
Navigate to this repository root directory and instruct Pixi to fetch and lock the execution dependencies:
```bash
pixi install
```

---

## Repository Layout

This workflow complies with the **Snakemake Workflow Standard**, separating workflow source logic from local system credentials using an automated template abstraction layer:

```text
snakemake-wps-eessi/
├── pixi.toml                # Project task and software package configuration
├── pixi.lock                # Pixi dependency tracking for increased reproducibility
├── config/
│   ├── config.yaml          # Target WPS version and CVMFS system paths
│   ├── README.md            # Slurm cluster credential discovery guide
│   └── profiles/
│       └── template_slurm/  # Base template configuration for any HPC cluster
│           └── config.yaml
└── workflow/
    └── Snakefile            # Granular rule execution dependency graph (DAG)
    └── scripts/
        └── audit.sh         # Audits EESSI environment to decide whether compile from official EasyBuild config & patches (EESSI_OFFICIAL) or local (FALLBACK_LOCAL)
        └── compile.sh       # WRF + WPS compilation
```

---

## Workflow Engine & Execution Stages

The workflow constructs a 2-stage execution matrix:

1. **Auditing (`workflow/audit.sh`)**: Interrogates CVMFS to determine if the build uses `EESSI_OFFICIAL` or `FALLBACK_LOCAL` resources.
2. **Compilation (`workflow/compile.sh`)**: Compiles WRF and WPS through EasyBuild.

### HPC Runtime Enforcements

- **Thread Control (`*_NUM_THREADS=1`)**: inhibits unmanaged thread spawning for math libraries.
- **Stack Memory `(ulimit -s unlimited`)**: protects against segmentation faults.


## Execution Guide

**1. Configure CVMFS & Versions**

Edit `config/config.yaml` to define your CVMFS init script, toolchain, and software versions.

**2. Customize Slurm Profiles**

Copy `config/profiles/template_slurm` to a new directory and update your cluster account/partition details.

**3. Execute**
- **Dry-run**: `pixi run dry-run config/profiles/<your-profile>`
- **Run on Slurm**: `pixi run run-slurm config/profiles/<your-profile>`
- **Run Local (Interactive)**: `pixi run run-local --cores 8`
