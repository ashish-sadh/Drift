"""TestFlight state accessors — last publish timestamp + unpublished commits count."""

from __future__ import annotations

import os
from pathlib import Path

from drift_mcp.runner import run_gh


def _stamp_file() -> Path:
    return Path(os.environ.get("HOME", "")) / "drift-state" / "last-testflight-publish"


def register(mcp) -> None:
    @mcp.tool()
    def testflight_last_published_at() -> dict:
        """Return unix timestamp of last successful TestFlight publish, or None if never."""
        f = _stamp_file()
        if not f.exists():
            return {"ok": True, "last_published_at": None}
        try:
            ts = int(f.read_text(encoding="utf-8").strip())
            return {"ok": True, "last_published_at": ts}
        except ValueError:
            return {"ok": True, "last_published_at": None, "warning": "stamp file unparseable"}

    @mcp.tool()
    def testflight_unpublished_commits() -> dict:
        """Return the count + shas of commits to main since the last published build."""
        import subprocess

        # Parse last-published sha (we write it alongside the timestamp in
        # the new /testflight-publish skill; if absent, count all commits to
        # main since the file's mtime).
        f = _stamp_file()
        if not f.exists():
            return {"ok": True, "count": 0, "shas": [], "reason": "no prior publish stamp"}
        # Look for an adjacent sha file
        sha_file = f.parent / "last-testflight-publish-sha"
        since_sha = None
        if sha_file.exists():
            since_sha = sha_file.read_text(encoding="utf-8").strip()
        if since_sha:
            cmd = ["git", "log", f"{since_sha}..HEAD", "--format=%H", "main"]
        else:
            # Fallback: commits since the stamp file's mtime
            import datetime as _dt

            mtime = _dt.datetime.fromtimestamp(f.stat().st_mtime).isoformat()
            cmd = ["git", "log", f"--since={mtime}", "--format=%H", "main"]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        except FileNotFoundError:
            return {"ok": False, "error_code": "GIT_MISSING"}
        shas = [s for s in result.stdout.strip().split("\n") if s]
        return {"ok": True, "count": len(shas), "shas": shas[:20]}
