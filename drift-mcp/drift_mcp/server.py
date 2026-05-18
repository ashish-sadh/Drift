"""drift-mcp entry point.

Wires every tool module onto a single FastMCP server. The server runs over
stdio by default — invoked by Claude Code via `.claude/mcp-config.json`.
"""

from __future__ import annotations

import sys

from mcp.server.fastmcp import FastMCP

from drift_mcp.tools import design, issues, reports, sprint, state, testflight, verify


def build_server() -> FastMCP:
    mcp = FastMCP("drift")
    sprint.register(mcp)
    design.register(mcp)
    issues.register(mcp)
    reports.register(mcp)
    state.register(mcp)
    verify.register(mcp)
    testflight.register(mcp)
    return mcp


def main() -> int:
    mcp = build_server()
    try:
        mcp.run()
    except KeyboardInterrupt:
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
