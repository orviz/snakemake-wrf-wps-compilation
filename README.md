# WRF & WPS Automated Deployment over EESSI with Snakemake

This repository provides a **Snakemake** workflow designed to compile both the **Weather Research and Forecasting (WRF) Model** and the **WRF Pre-processing System (WPS)** directly on top of the **EESSI (European Environment for Scientific Software Installations)** shared stack via CVMFS.

By leveraging optimized host-injection toolchains (such as `foss/2024a`), this workflow dynamically audits the centralized EESSI environment to determine whether to utilize official distributed EasyConfigs or seamlessly inject local fallbacks.

---

## Dual WRF and WPS Software Compilation

The architecture of the `Snakefile` is designed to process **both WRF and WPS simultaneously** using Snakemake wildcards and parallel directed acyclic graphs (DAGs).

### Features

1. **WRF/WPS Auditing**: It forks two parallel auditing processes to independently check the CVMFS status for both `WPS` (v4.6.0) and `WRF` (v4.6.1).
2. **Independent Fallbacks**: If EESSI contains one software but lacks the other, the workflow uses the official centralized build for the former while triggering a local recipe fallback (`.eb` + patches) exclusively for the latter.
3. **Self-Contained Deployment**: The pipeline isolates and drives the building process into your custom `wps_install_dir` and `wrf_install_dir` targets, keeping the environment completely self-contained. Once completed, it scans the build tree to establish symlinks strictly inside the local `[wps|wrf]_install_dir/bin/` directory.


---

## Environment Architecture

This project relies on **Pixi** to deploy the WPS/WRF software in an isolated Python environment.

### 1. Install Pixi (One-time setup per user)
If not available, make sure Pixi is deployed before triggering the compilation:
```bash
curl -fsSL https://pixi.sh/install.sh | sh
source ~/.bashrc
```

### 2. Clone this repository

Clone this project into your scratch or home space:

```bash
git clone https://github.com/orviz/snakemake-wrf-wps-compilation
cd snakemake-wrf-wps-compilation
```

### 3. Workspace Initialization
Navigate to this repository root directory and instruct Pixi to fetch and lock the execution dependencies:
```bash
pixi install
```

*Note: this step is not required if you use [any of the `pixi run` commands below](#2-workflow-execution).*

---

## Repository Layout

This workflow complies with the **Snakemake Workflow Standard**, separating workflow source logic from local system credentials using an automated template abstraction layer:

```text
snakemake-wrf-wps-compilation/
└── workflow/
    └── Snakefile            # Granular rule execution dependency graph (DAG)
    └── scripts/
        └── audit.sh         # Audits EESSI environment to decide whether compile from official EasyBuild config & patches (EESSI_OFFICIAL) or local (FALLBACK_LOCAL)
        └── compile.sh       # WRF + WPS compilation
├── config/
│   ├── config.yaml          # Target WPS version and CVMFS system paths
│   ├── README.md            # Slurm cluster credential discovery guide
│   └── profiles/            # Base template configuration for different HPC clusters, populated from `hpc-profiles` branch through Git Worktrees
│       └── ...
├── pixi.toml                # Project task and software package configuration
├── pixi.lock                # Pixi dependency tracking for increased reproducibility
```

---

## Workflow Engine & Execution Stages

The workflow constructs a 2-stage execution matrix:

1. **Auditing (`workflow/audit.sh`)**: Interrogates CVMFS to determine if the build uses `EESSI_OFFICIAL` or `FALLBACK_LOCAL` resources.
2. **Compilation (`workflow/compile.sh`)**: Compiles WRF and WPS through EasyBuild.

### HPC Runtime Enforcements

- **Thread Control (`*_NUM_THREADS=1`)**: manages thread spawning for math libraries.
- **Stack Memory `(ulimit -s unlimited`)**: protects against segmentation faults.

## Execution Guide

### 1. Configure CVMFS & Versions

Edit [`config/config.yaml`](./config/config.yaml) to define your CVMFS init script, toolchain, and software versions.

### 2. Workflow Execution (Local, Cloud)

The workflow can be executed locally or on the Cloud as follows:

```bash
# Dry run to preview the execution plan
pixi run dry-run

# Execute locally using default cores
pixi run run-local

# Execute locally passing custom Snakemake arguments
pixi run run-local --cores 4
```

### 3. Workflow Execution (HPC)

Within HPC, it is recommended to leverage Snakemake profiles. This module relies on *Git Worktrees* to decouple workflow logic from the specific HPC-related configuration. The **HPC profiles live in the `hpc-profiles` branch**.

**1. Embed the HPC profile**

For instance, in order to initialize Altamira cluster profile configuration:

```bash
git worktree add config/profiles hpc-profiles
```

The command above will populate `config/profiles/` with the available cluster configurations (e.g., altamira/), each containing its own Slurm presets and a `set_env.sh` file.

**2. Launch the Simulation**

To execute the workflow, use the unified Pixi's `hpc-profile` task. Pass the name of the HPC profile as the first argument, followed by any optional Snakemake flags:

```bash
# Standard execution on Altamira
pixi run hpc-profile altamira

# Dry-run execution on Altamira
pixi run hpc-profile altamira --dry-run

# Execution limiting concurrent Slurm jobs
pixi run hpc-profile altamira --jobs 15
```

## Working with Snakemake Profiles (Git Worktree)

Once the Git Worktree is set up, any update in the configuration of any HPC profile will work as follows:

- **Download configuration updates:**

```bash
cd config/profiles/altamira
git pull origin hpc-profiles
```

- **Upload configuration changes:**

```bash
cd config/profiles/altamira
# E.g. modify config.yaml...
git add config.yaml
git commit -m "Increase memory limits for WRF simulation"
git push origin hpc-profiles
```

To **create a new profile**, copy and modify appropiately the `config/profiles/template_slurm` template, and finally, add it to the `hpc-profiles` branch.
