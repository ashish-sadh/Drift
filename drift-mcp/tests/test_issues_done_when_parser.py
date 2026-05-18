"""Contract test for the Done-When XML parser inside issues._parse_done_when.

This is the most load-bearing piece of new logic — verifier scores against it,
require-done-when.sh hook blocks claim without it. Test it directly without
spinning up the MCP server.
"""

from __future__ import annotations

import pytest

from drift_mcp.tools.issues import _parse_done_when


def test_done_when_basic():
    body = """
Some markdown context here.

<done_when threshold="weight_sum>=5 AND no_criterion_at_zero">
  <criterion id="1" weight="3" verify="cd DriftCore && swift test --filter ThemeFlipTests">
    New tier-0 test added covering the goal-aware color flip.
  </criterion>
  <criterion id="2" weight="2" verify="true">
    Tier-1 iOS tests pass.
  </criterion>
</done_when>

More markdown.
""".strip()
    result = _parse_done_when(body)
    assert result["ok"] is True
    assert result["is_permanent"] is False
    assert result["threshold"] == "weight_sum>=5 AND no_criterion_at_zero"
    assert len(result["criteria"]) == 2
    assert result["criteria"][0]["id"] == "1"
    assert result["criteria"][0]["weight"] == 3
    assert "ThemeFlipTests" in result["criteria"][0]["verify"]
    assert "goal-aware color flip" in result["criteria"][0]["description"]


def test_done_when_missing():
    body = "No tags here. Just plain markdown."
    result = _parse_done_when(body)
    assert result["ok"] is False
    assert result["error_code"] == "NO_DONE_WHEN_BLOCK"


def test_progress_when_for_permanent_task():
    body = """
This is a permanent task.

<progress_when>
  <criterion id="1" weight="1" verify="true">
    Made measurable progress this cycle.
  </criterion>
</progress_when>
""".strip()
    result = _parse_done_when(body)
    assert result["ok"] is True
    assert result["is_permanent"] is True
    assert len(result["criteria"]) == 1


def test_done_when_with_xml_entities_in_verify():
    body = """
<done_when>
  <criterion id="1" weight="2" verify="xcodebuild test 2>&amp;1 | grep '✘' | wc -l">
    iOS tests pass.
  </criterion>
</done_when>
""".strip()
    result = _parse_done_when(body)
    assert result["ok"] is True
    assert "2>&1" in result["criteria"][0]["verify"]


def test_done_when_threshold_omitted():
    body = """
<done_when>
  <criterion id="1" weight="3" verify="true">Stuff.</criterion>
</done_when>
""".strip()
    result = _parse_done_when(body)
    assert result["ok"] is True
    assert result["threshold"] == ""
