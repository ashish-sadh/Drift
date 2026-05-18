"""Report PR operations — exec briefings + product reviews."""

from __future__ import annotations

from drift_mcp.runner import require_autonomous, run_script


def register(mcp) -> None:
    @mcp.tool()
    def reports_start_review(cycle_n: int) -> dict:
        """Create a branch + scaffold file for a product review at cycle N."""
        gate = require_autonomous("reports_start_review")
        if gate:
            return gate
        result = run_script("scripts/report-service.sh", ["start-review", str(cycle_n)])
        return {"ok": result["ok"], "stdout": result["stdout"].strip()}

    @mcp.tool()
    def reports_start_exec(date: str) -> dict:
        """Create a branch + scaffold file for a daily exec report on `date` (YYYY-MM-DD)."""
        gate = require_autonomous("reports_start_exec")
        if gate:
            return gate
        result = run_script("scripts/report-service.sh", ["start-exec", date])
        return {"ok": result["ok"], "stdout": result["stdout"].strip()}

    @mcp.tool()
    def reports_finish(branch: str) -> dict:
        """Open a PR for the named report branch and merge atomically."""
        gate = require_autonomous("reports_finish")
        if gate:
            return gate
        result = run_script("scripts/report-service.sh", ["finish", branch])
        return {"ok": result["ok"], "stdout": result["stdout"].strip()}
