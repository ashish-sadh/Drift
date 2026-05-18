"""Contract test for the verdict XML parser inside verify._parse_verdict."""

from __future__ import annotations

from drift_mcp.tools.verify import _parse_verdict


def test_verdict_pass():
    body = """
Some prose from the verifier.

<verifier_verdict decision="PASS">
  <scores>
    <score criterion="1" weight="3" earned="3"/>
    <score criterion="2" weight="2" earned="2"/>
  </scores>
  <reasoning>All criteria met cleanly.</reasoning>
</verifier_verdict>
""".strip()
    v = _parse_verdict(body)
    assert v is not None
    assert v["decision"] == "PASS"
    assert len(v["scores"]) == 2
    assert v["scores"][0] == {"criterion": "1", "weight": 3, "earned": 3}
    assert "cleanly" in v["reasoning"]


def test_verdict_reject_with_zero_criterion():
    body = """
<verifier_verdict decision="REJECT">
  <scores>
    <score criterion="1" weight="3" earned="0"/>
    <score criterion="2" weight="2" earned="2"/>
  </scores>
  <fix_items>
    <item criterion="1">Add the missing test.</item>
  </fix_items>
  <reasoning>Criterion 1 at 0 → REJECT regardless of weight-sum.</reasoning>
</verifier_verdict>
""".strip()
    v = _parse_verdict(body)
    assert v is not None
    assert v["decision"] == "REJECT"
    # Critically: criterion 1 at 0 must surface in scores
    score_1 = next(s for s in v["scores"] if s["criterion"] == "1")
    assert score_1["earned"] == 0
    assert len(v["fix_items"]) == 1
    assert v["fix_items"][0]["criterion"] == "1"
    assert "missing test" in v["fix_items"][0]["description"]


def test_verdict_missing_returns_none():
    body = "Just prose, no verdict block."
    assert _parse_verdict(body) is None


def test_verdict_malformed_returns_none_gracefully():
    body = "<verifier_verdict decision='FIX'>incomplete xml"
    # lxml HTMLParser is forgiving; should still extract decision attribute
    v = _parse_verdict(body)
    assert v is not None
    assert v["decision"] == "FIX"
