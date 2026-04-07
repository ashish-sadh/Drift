#!/usr/bin/env python3
"""
Validate, deduplicate, and split training data into train/eval sets.

Usage:
    python data/validate_data.py data/all_generated.jsonl
    python data/validate_data.py data/all_generated.jsonl --split 0.9
"""

import argparse
import json
import random
import sys
from collections import Counter
from pathlib import Path

VALID_TOOLS = {"log_food", "food_info", "log_weight", "weight_info",
               "start_workout", "exercise_info", "sleep_recovery", "supplements"}


def validate_example(item: dict, line_num: int) -> list[str]:
    """Return list of validation errors for a single example."""
    errors = []

    # Required fields
    for field in ("system", "user", "assistant", "category"):
        if field not in item:
            errors.append(f"L{line_num}: missing field '{field}'")

    if errors:
        return errors

    # Check assistant response format
    assistant = item["assistant"]
    category = item["category"]

    if category in ("no_tool", "hard_negatives"):
        # Should NOT contain a tool call
        if '{"tool"' in assistant:
            errors.append(f"L{line_num}: no-tool category has tool call in response")
    else:
        # Should contain a valid tool call JSON
        try:
            call = json.loads(assistant)
            if "tool" not in call:
                errors.append(f"L{line_num}: tool call missing 'tool' key")
            elif call["tool"] not in VALID_TOOLS:
                errors.append(f"L{line_num}: unknown tool '{call['tool']}'")
            if "params" not in call:
                errors.append(f"L{line_num}: tool call missing 'params' key")
        except json.JSONDecodeError:
            errors.append(f"L{line_num}: assistant response is not valid JSON: {assistant[:60]}")

    # Check system prompt has tool schemas
    if "Tools:" not in item["system"]:
        errors.append(f"L{line_num}: system prompt missing tool schemas")

    # Check user prompt format
    if "User:" not in item["user"]:
        errors.append(f"L{line_num}: user prompt missing 'User:' prefix")

    return errors


def deduplicate(data: list[dict]) -> list[dict]:
    """Remove near-duplicate user queries (case-insensitive exact match)."""
    seen = set()
    unique = []
    dupes = 0
    for item in data:
        query = item.get("query", item["user"]).lower().strip()
        if query in seen:
            dupes += 1
            continue
        seen.add(query)
        unique.append(item)
    if dupes:
        print(f"  Removed {dupes} duplicate queries")
    return unique


def main():
    parser = argparse.ArgumentParser(description="Validate and split training data")
    parser.add_argument("input", type=str, help="Input JSONL file")
    parser.add_argument("--split", type=float, default=0.9, help="Train fraction (default 0.9)")
    parser.add_argument("--train-output", type=str, default="data/train.jsonl")
    parser.add_argument("--eval-output", type=str, default="data/eval.jsonl")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for split")
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"❌ File not found: {input_path}")
        sys.exit(1)

    # Load
    data = []
    with open(input_path) as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                data.append(json.loads(line))
            except json.JSONDecodeError:
                print(f"  ⚠️  Line {i}: invalid JSON, skipping")

    print(f"Loaded {len(data)} examples from {input_path}")

    # Validate
    total_errors = 0
    valid_data = []
    for i, item in enumerate(data, 1):
        errors = validate_example(item, i)
        if errors:
            for e in errors:
                print(f"  ❌ {e}")
            total_errors += len(errors)
        else:
            valid_data.append(item)

    print(f"\nValidation: {len(valid_data)} valid, {total_errors} errors")

    # Deduplicate
    valid_data = deduplicate(valid_data)

    # Category distribution
    cats = Counter(item["category"] for item in valid_data)
    print(f"\nCategory distribution ({len(valid_data)} total):")
    for cat, count in sorted(cats.items()):
        pct = count / len(valid_data) * 100
        print(f"  {cat:20s}: {count:4d} ({pct:.1f}%)")

    # Split
    random.seed(args.seed)
    random.shuffle(valid_data)
    split_idx = int(len(valid_data) * args.split)
    train_data = valid_data[:split_idx]
    eval_data = valid_data[split_idx:]

    # Write train
    train_path = Path(args.train_output)
    train_path.parent.mkdir(parents=True, exist_ok=True)
    with open(train_path, "w") as f:
        for item in train_data:
            f.write(json.dumps(item) + "\n")

    # Write eval
    eval_path = Path(args.eval_output)
    eval_path.parent.mkdir(parents=True, exist_ok=True)
    with open(eval_path, "w") as f:
        for item in eval_data:
            f.write(json.dumps(item) + "\n")

    print(f"\nSplit: {len(train_data)} train → {train_path}")
    print(f"       {len(eval_data)} eval  → {eval_path}")

    # Eval category distribution
    eval_cats = Counter(item["category"] for item in eval_data)
    print(f"\nEval distribution:")
    for cat, count in sorted(eval_cats.items()):
        print(f"  {cat:20s}: {count:4d}")


if __name__ == "__main__":
    main()
