import shutil
from pathlib import Path
from snakemake.exceptions import WorkflowError


def create_master_link(target_dir, source_dir, remove_existing=False):
    target = Path(target_dir)
    source = Path(source_dir).resolve()

    # Verify that the source exists.
    if not source.is_dir():
        raise WorkflowError(
            f"Link source does not exist or is not a directory: {source}"
        )

    # Ensure the parent directory exists.
    target.parent.mkdir(parents=True, exist_ok=True)

    if target.is_symlink() and target.resolve() == source:
        print(f"[Link] Link is correct: {target} -> {source}")
        return

    if target.is_symlink():
        print(f"[Link] Replace incorrect link: {target}")
        target.unlink()

    elif target.exists():
        if not target.is_dir():
            raise WorkflowError(
                f"Link destination exists and is not a directory: {target}"
            )

        if not remove_existing:
            raise WorkflowError(
                f"################################################################\n"
                f"\nDestination '{target}' already exists as a real directory.\n"
                f"It has NOT been deleted.\n\n"
                f"To resolve this manually, inspect its contents and then:\n"
                f"  1. Back up any data you need.\n"
                f"  2. Rename or move the directory, for example:\n"
                f"     mv '{target}' '{target}.backup'\n"
                f"  3. Re-run the Snakemake workflow.\n\n"
                f"Alternatively, enable 'links:remove_existing_directories' in "
                f"config.yaml, understanding that this may permanently delete "
                f"data."
                f"################################################################\n"
            )

        print(
            f"[WARNING] Removing existing directory '{target}' "
            f"because 'links.remove_existing_directories' parameter is enabled in config.yaml."
        )
        shutil.rmtree(target)

    target.symlink_to(source, target_is_directory=True)

    print(f"[Link] Created link: {target} -> {source}")

def reconcile_existing_link(target_dir, source_dir, remove_existing=False):
    source = Path(source_dir)

    # In a initial compilation, the installation may not exist yet.
    # The link rule will create it when it becomes available.
    if source.is_dir():
        create_master_link(
            target_dir,
            source_dir,
            remove_existing=remove_existing,
        )


def reconcile_master_links():
    remove_existing = config.get("links", {}).get(
        "remove_existing_directories", False
    )

    reconcile_existing_link(
        WPS_INSTALL_DIR,
        ENGINE_WPS_ROOT,
        remove_existing,
    )
    reconcile_existing_link(
        WRF_INSTALL_DIR,
        ENGINE_WRF_ROOT,
        remove_existing,
    )