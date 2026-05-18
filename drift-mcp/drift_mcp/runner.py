"""Shared subprocess helper for shelling out to Drift bash scripts.

Every tool that wraps a bash CLI uses `run_script` to get structured stdout +
stderr + exit code. The helper:
  - Runs from $DRIFT_REPO (defaults to env var, falls back to ../.. relative to this file)
  - Captures stdout and stderr separately
  - Returns a dict so the tool can shape it for the MCP response without re-parsing
"""

from __future__ import annotations

import os
import shlex
import subprocess
from pathlib import Path


def repo_root() -> Path:
    env = os.environ.get("DRIFT_REPO")
    if env:
        return Path(env).resolve()
    # drift-mcp/drift_mcp/runner.py -> repo is two levels up
    return Path(__file__).resolve().parent.parent.parent


def is_autonomous() -> bool:
    return os.environ.get("DRIFT_AUTONOMOUS", "0") == "1"


def run_script(script_relpath: str, args: list[str], timeout: int = 60) -> dict:
    """Run a script under $DRIFT_REPO/$script_relpath with args; return structured result.

    Returns:
        {
            "ok": bool,            # exit code 0
            "exit": int,
            "stdout": str,
            "stderr": str,
            "cmd": str,            # for debugging
        }
    """
    cwd = repo_root()
    script = cwd / script_relpath
    if not script.exists():
        return {
            "ok": False,
            "exit": -1,
            "stdout": "",
            "stderr": f"script not found: {script}",
            "cmd": f"{script} {' '.join(shlex.quote(a) for a in args)}",
        }
    cmd = [str(script), *args]
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as e:
        return {
            "ok": False,
            "exit": -1,
            "stdout": e.stdout or "",
            "stderr": f"timeout after {timeout}s: {e.stderr or ''}",
            "cmd": " ".join(shlex.quote(c) for c in cmd),
        }
    return {
        "ok": result.returncode == 0,
        "exit": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "cmd": " ".join(shlex.quote(c) for c in cmd),
    }


def run_gh(args: list[str], timeout: int = 30) -> dict:
    """Run `gh ...` directly. Same return shape as run_script."""
    cmd = ["gh", *args]
    try:
        result = subprocess.run(
            cmd,
            cwd=repo_root(),
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as e:
        return {
            "ok": False,
            "exit": -1,
            "stdout": e.stdout or "",
            "stderr": f"timeout after {timeout}s: {e.stderr or ''}",
            "cmd": " ".join(shlex.quote(c) for c in cmd),
        }
    return {
        "ok": result.returncode == 0,
        "exit": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "cmd": " ".join(shlex.quote(c) for c in cmd),
    }


def require_autonomous(tool_name: str) -> dict | None:
    """Permission gate for mutating tools. Returns an error dict if blocked, else None."""
    if not is_autonomous():
        return {
            "ok": False,
            "error_code": "NOT_AUTONOMOUS",
            "message": (
                f"{tool_name}: mutation refused outside autonomous mode "
                "(set DRIFT_AUTONOMOUS=1 in the watchdog spawn env)"
            ),
        }
    return None
