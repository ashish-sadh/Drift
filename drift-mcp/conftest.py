"""pytest config: put drift_mcp package on sys.path for in-tree tests."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
