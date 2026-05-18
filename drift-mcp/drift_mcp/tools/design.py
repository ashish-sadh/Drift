"""Design-doc lifecycle operations — wraps scripts/design-service.sh."""

from __future__ import annotations

from drift_mcp.runner import require_autonomous, run_script


def register(mcp) -> None:
    @mcp.tool()
    def design_list_pending() -> dict:
        """List design-doc issues that have no doc-ready label yet."""
        result = run_script("scripts/design-service.sh", ["pending"])
        return {"ok": result["ok"], "stdout": result["stdout"].strip()}

    @mcp.tool()
    def design_list_in_review() -> dict:
        """List design-doc PRs that have unaddressed comments."""
        result = run_script("scripts/design-service.sh", ["in-review"])
        return {"ok": result["ok"], "stdout": result["stdout"].strip()}

    @mcp.tool()
    def design_list_approved_not_started() -> dict:
        """List approved design docs with no impl tasks filed."""
        result = run_script("scripts/design-service.sh", ["approved-not-started"])
        return {"ok": result["ok"], "stdout": result["stdout"].strip()}

    @mcp.tool()
    def design_address_pr(pr: int) -> dict:
        """Dump all comment surfaces (issue comments, inline threads, review bodies) for a design-doc PR.

        Returns the raw text dump — the calling skill processes it. Senior is expected
        to read this in a fresh-context-friendly way (file-based, never re-feed thread).
        """
        result = run_script("scripts/design-service.sh", ["address-pr", str(pr)])
        return {
            "ok": result["ok"],
            "stdout": result["stdout"],
            "stderr": result["stderr"].strip() if result["stderr"] else "",
        }

    @mcp.tool()
    def design_check_complete(design_n: int) -> dict:
        """Check whether all design-impl-{N} tasks for a design doc have closed."""
        result = run_script(
            "scripts/design-service.sh", ["check-complete", str(design_n)]
        )
        return {"ok": result["ok"], "stdout": result["stdout"].strip()}
