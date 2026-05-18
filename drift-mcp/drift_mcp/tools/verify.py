"""Verifier verdict parsing + cached tier-0 test runner."""

from __future__ import annotations

import json
import time
from pathlib import Path

from lxml import etree

from drift_mcp.runner import repo_root, run_gh, run_script


_TIER0_CACHE_FILE = Path("/tmp/drift_mcp_tier0_cache.json")


def _parse_verdict(comment_body: str) -> dict | None:
    """Pull the latest <verifier_verdict ...>...</verifier_verdict> from a comment body."""
    if "<verifier_verdict" not in comment_body:
        return None
    parser = etree.HTMLParser(recover=True)
    try:
        root = etree.fromstring(f"<root>{comment_body}</root>", parser)
    except etree.XMLSyntaxError:
        return None
    if root is None:
        return None
    block = root.find(".//verifier_verdict")
    if block is None:
        return None
    scores = []
    for s in block.findall(".//score"):
        scores.append(
            {
                "criterion": s.get("criterion", ""),
                "weight": int(s.get("weight", "0")),
                "earned": int(s.get("earned", "0")),
            }
        )
    fix_items = [
        {
            "criterion": item.get("criterion", ""),
            "description": (item.text or "").strip(),
        }
        for item in block.findall(".//fix_items/item")
    ]
    reasoning = block.findtext("reasoning", default="").strip()
    return {
        "decision": block.get("decision", ""),
        "scores": scores,
        "fix_items": fix_items,
        "reasoning": reasoning,
    }


def register(mcp) -> None:
    @mcp.tool()
    def verify_parse_verdict(issue: int) -> dict:
        """Return the latest <verifier_verdict> block from `issue`'s comments, or none."""
        result = run_gh(["issue", "view", str(issue), "--json", "comments"])
        if not result["ok"]:
            return {"ok": False, "error_code": "GH_FETCH_FAILED", "message": result["stderr"]}
        try:
            data = json.loads(result["stdout"])
        except json.JSONDecodeError as e:
            return {"ok": False, "error_code": "JSON_PARSE_FAILED", "message": str(e)}
        comments = data.get("comments", []) or []
        # Walk comments newest first; return first verdict found.
        for c in reversed(comments):
            verdict = _parse_verdict(c.get("body", ""))
            if verdict:
                return {
                    "ok": True,
                    "verdict": verdict,
                    "comment_at": c.get("createdAt", ""),
                }
        return {"ok": True, "verdict": None}

    @mcp.tool()
    def verify_tier0_passing(ttl_sec: int = 300) -> dict:
        """Return tier-0 pass/fail. Cached for `ttl_sec` to avoid re-running on every check."""
        now = time.time()
        if _TIER0_CACHE_FILE.exists():
            try:
                cache = json.loads(_TIER0_CACHE_FILE.read_text())
                if now - cache.get("at", 0) < ttl_sec:
                    return {
                        "ok": True,
                        "passing": cache["passing"],
                        "last_run_at": cache["at"],
                        "cached": True,
                        "output_tail": cache.get("output_tail", ""),
                    }
            except (json.JSONDecodeError, KeyError):
                pass
        # Run swift test (tier 0)
        result = run_script_swift_test()
        tail_lines = (result["stdout"] + "\n" + result["stderr"]).strip().splitlines()[-30:]
        passing = result["ok"]
        cache = {
            "at": now,
            "passing": passing,
            "output_tail": "\n".join(tail_lines),
        }
        _TIER0_CACHE_FILE.write_text(json.dumps(cache))
        return {
            "ok": True,
            "passing": passing,
            "last_run_at": now,
            "cached": False,
            "output_tail": cache["output_tail"],
        }


def run_script_swift_test() -> dict:
    import subprocess

    cwd = repo_root() / "DriftCore"
    try:
        result = subprocess.run(
            ["swift", "test", "--quiet"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=300,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "exit": -1, "stdout": "", "stderr": "swift test timeout"}
    return {
        "ok": result.returncode == 0,
        "exit": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }
