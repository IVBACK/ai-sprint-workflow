import os
from pathlib import Path


def find_project_root(start: Path = None) -> Path:
    """Walk up from start to find directory containing TRACKING.md or CLAUDE.md."""
    current = (start or Path.cwd()).resolve()
    for d in [current, *current.parents]:
        if (d / "TRACKING.md").exists() or (d / "CLAUDE.md").exists():
            return d
    raise FileNotFoundError(
        "No TRACKING.md or CLAUDE.md found in parent directories"
    )


def find_tracking_file(root: Path, member: str = "") -> Path:
    """Find tracking file, supporting team mode via SPRINT_MEMBER env var."""
    member = member or os.environ.get("SPRINT_MEMBER", "")
    if member:
        candidate = root / f"TRACKING-{member}.md"
        if candidate.exists():
            return candidate
    return root / "TRACKING.md"
