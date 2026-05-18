"""GitHub Issue operations — feedback drain, label/comment mutations, Done-When parsing."""

from __future__ import annotations

import json

from lxml import etree

from drift_mcp.runner import require_autonomous, run_gh, run_script


def _parse_done_when(body: str) -> dict:
    """Parse the <done_when> block from an issue body. Returns structured criteria.

    Returns `{ok: false, error_code}` if no block is found or XML is malformed.
    """
    if "<done_when" not in body and "<progress_when" not in body:
        return {"ok": False, "error_code": "NO_DONE_WHEN_BLOCK"}
    # Wrap in a root so we can tolerate surrounding markdown
    snippet = body
    # Extract just the tag — lxml needs a single root
    parser = etree.HTMLParser(recover=True)
    try:
        root = etree.fromstring(f"<root>{snippet}</root>", parser)
    except etree.XMLSyntaxError as e:
        return {"ok": False, "error_code": "MALFORMED_XML", "message": str(e)}
    if root is None:
        return {"ok": False, "error_code": "PARSE_FAILED"}
    tag_name = "done_when"
    block = root.find(f".//{tag_name}")
    is_permanent = False
    if block is None:
        block = root.find(".//progress_when")
        is_permanent = True
    if block is None:
        return {"ok": False, "error_code": "NO_DONE_WHEN_BLOCK"}
    threshold = block.get("threshold", "")
    criteria = []
    for c in block.findall(".//criterion"):
        criteria.append(
            {
                "id": c.get("id", ""),
                "weight": int(c.get("weight", "1")),
                "verify": c.get("verify", ""),
                "description": (c.text or "").strip(),
            }
        )
    return {
        "ok": True,
        "is_permanent": is_permanent,
        "threshold": threshold,
        "criteria": criteria,
    }


def register(mcp) -> None:
    @mcp.tool()
    def issues_drain_feedback() -> dict:
        """Scan recent admin comments + feature-requests for systemic patterns to file as infra-improvements."""
        gate = require_autonomous("issues_drain_feedback")
        if gate:
            return gate
        result = run_script("scripts/issue-service.sh", ["drain-feedback"])
        return {"ok": result["ok"], "stdout": result["stdout"].strip()}

    @mcp.tool()
    def issues_add_label(issue: int, label: str) -> dict:
        """Add a label to an issue."""
        gate = require_autonomous("issues_add_label")
        if gate:
            return gate
        result = run_gh(["issue", "edit", str(issue), "--add-label", label])
        return {"ok": result["ok"], "stderr": result["stderr"].strip()}

    @mcp.tool()
    def issues_remove_label(issue: int, label: str) -> dict:
        """Remove a label from an issue."""
        gate = require_autonomous("issues_remove_label")
        if gate:
            return gate
        result = run_gh(["issue", "edit", str(issue), "--remove-label", label])
        return {"ok": result["ok"], "stderr": result["stderr"].strip()}

    @mcp.tool()
    def issues_comment(issue: int, body: str, wip: bool = False) -> dict:
        """Post a comment on an issue. `wip=True` prepends a `<wip/>` marker so downstream gates can skip it."""
        gate = require_autonomous("issues_comment")
        if gate:
            return gate
        prefixed = f"<wip/>\n\n{body}" if wip else body
        result = run_gh(["issue", "comment", str(issue), "--body", prefixed])
        return {"ok": result["ok"], "stderr": result["stderr"].strip()}

    @mcp.tool()
    def issues_read_done_when(issue: int) -> dict:
        """Parse the <done_when> (or <progress_when>) block from an issue body.

        Returns structured criteria. The calling skill uses this as ground truth
        for what "done" means; the verifier scores against these criteria.
        """
        result = run_gh(["issue", "view", str(issue), "--json", "body"])
        if not result["ok"]:
            return {"ok": False, "error_code": "GH_FETCH_FAILED", "message": result["stderr"]}
        try:
            data = json.loads(result["stdout"])
        except json.JSONDecodeError as e:
            return {"ok": False, "error_code": "JSON_PARSE_FAILED", "message": str(e)}
        body = data.get("body", "") or ""
        return _parse_done_when(body)
