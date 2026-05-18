"""Tool modules grouped by domain.

Each module exposes a `register(mcp)` function that wires its tools onto the
FastMCP server. Keeping registration explicit (rather than discovery-by-decorator)
makes the tool inventory readable from server.py at a glance.
"""
