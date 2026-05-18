"""Sprint queue operations — wraps scripts/sprint-service.sh."""

from __future__ import annotations

from drift_mcp.runner import require_autonomous, run_script


def register(mcp) -> None:
    @mcp.tool()
    def sprint_claim(role: str, issue: int | None = None) -> dict:
        """Claim the top-of-queue task for `role` (senior|junior), or a specific `issue`.

        Returns structured `{ok, issue, branch, started_at}` on success or
        `{ok: false, error_code, message}` on failure (already-claimed, paused, etc).
        """
        gate = require_autonomous("sprint_claim")
        if gate:
            return gate
        args = [f"--{role}", "--claim"]
        if issue is not None:
            args.append(str(issue))
        result = run_script("scripts/sprint-service.sh", ["next", *args])
        return {
            "ok": result["ok"],
            "stdout": result["stdout"].strip(),
            "stderr": result["stderr"].strip() if result["stderr"] else "",
            "exit": result["exit"],
        }

    @mcp.tool()
    def sprint_next(role: str) -> dict:
        """Peek the top-of-queue task for `role` without claiming it."""
        result = run_script("scripts/sprint-service.sh", ["next", f"--{role}"])
        return {
            "ok": result["ok"],
            "stdout": result["stdout"].strip(),
            "stderr": result["stderr"].strip() if result["stderr"] else "",
        }

    @mcp.tool()
    def sprint_done(issue: int, resolution_comment: str) -> dict:
        """Mark a one-shot sprint-task issue done with a resolution comment."""
        gate = require_autonomous("sprint_done")
        if gate:
            return gate
        result = run_script(
            "scripts/sprint-service.sh",
            ["done", str(issue), "--message", resolution_comment],
        )
        return {
            "ok": result["ok"],
            "stdout": result["stdout"].strip(),
            "stderr": result["stderr"].strip() if result["stderr"] else "",
        }

    @mcp.tool()
    def sprint_session_done(issue: int, progress_comment: str) -> dict:
        """Mark progress on a permanent-task issue (issue stays open)."""
        gate = require_autonomous("sprint_session_done")
        if gate:
            return gate
        result = run_script(
            "scripts/sprint-service.sh",
            ["session-done", str(issue), "--message", progress_comment],
        )
        return {
            "ok": result["ok"],
            "stdout": result["stdout"].strip(),
            "stderr": result["stderr"].strip() if result["stderr"] else "",
        }

    @mcp.tool()
    def sprint_abandon(issue: int, reason: str) -> dict:
        """Abandon a claimed issue back to the queue.

        Unclaims the issue, posts an `<abandoned>` comment, increments the
        abandonment counter on the issue. After 3 abandonments the issue is
        auto-labeled `needs-human` and removed from the autopilot queue.
        """
        gate = require_autonomous("sprint_abandon")
        if gate:
            return gate
        result = run_script(
            "scripts/sprint-service.sh",
            ["abandon", str(issue), "--reason", reason],
        )
        return {
            "ok": result["ok"],
            "stdout": result["stdout"].strip(),
            "stderr": result["stderr"].strip() if result["stderr"] else "",
        }

    @mcp.tool()
    def sprint_status() -> dict:
        """Return current sprint queue counts (pending/in-progress/done by label)."""
        result = run_script("scripts/sprint-service.sh", ["status"])
        return {
            "ok": result["ok"],
            "stdout": result["stdout"].strip(),
        }

    @mcp.tool()
    def sprint_refresh() -> dict:
        """Refresh the local sprint-state cache from GitHub."""
        result = run_script("scripts/sprint-service.sh", ["refresh"])
        return {
            "ok": result["ok"],
            "stdout": result["stdout"].strip(),
        }
