#!/usr/bin/env python3
"""
Continuous improvement loop — inspired by Autoresearch.
Generate targeted data → train → eval → keep/discard → repeat.

Usage:
    python loop.py --config config/qwen2.5-1.5b.yaml
    python loop.py --config config/qwen2.5-1.5b.yaml --cycles 10
    python loop.py --config config/qwen2.5-1.5b.yaml --data-only  # just generate data, don't train
"""

import argparse
import csv
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import yaml

RESULTS_FILE = "results.tsv"
CATEGORIES = [
    "food_logging", "food_questions", "weight_logging", "weight_questions",
    "exercise_start", "exercise_questions", "sleep_recovery", "supplements",
    "no_tool", "hard_negatives",
]


def read_steering() -> dict:
    """Read program.md for steering notes."""
    steering = {"model": "qwen2.5-1.5b", "focus": [], "data_budget": 200, "override": "CONTINUE"}
    program_path = Path("program.md")
    if not program_path.exists():
        return steering

    text = program_path.read_text()
    for line in text.split("\n"):
        line = line.strip().lstrip("- ")
        if line.startswith("model:"):
            steering["model"] = line.split(":", 1)[1].strip()
        elif line.startswith("focus:"):
            steering["focus"] = [x.strip() for x in line.split(":", 1)[1].split(",")]
        elif line.startswith("data_budget:"):
            steering["data_budget"] = int(line.split(":", 1)[1].strip())
        elif line.startswith("override:"):
            steering["override"] = line.split(":", 1)[1].strip()

    return steering


def get_last_result() -> dict | None:
    """Read the last result from results.tsv."""
    results_path = Path(RESULTS_FILE)
    if not results_path.exists():
        return None

    with open(results_path) as f:
        reader = csv.DictReader(f, delimiter="\t")
        rows = list(reader)

    if not rows:
        return None
    return rows[-1]


def find_weakest_category(last_result: dict | None, focus: list[str]) -> str:
    """Find the weakest category to focus data generation on."""
    if not last_result:
        # First run — focus on historically weakest
        return "exercise_start"

    # Parse per-category scores from last result
    scores = {}
    for cat in CATEGORIES:
        val = last_result.get(cat, "")
        if val:
            try:
                scores[cat] = float(val)
            except ValueError:
                pass

    if not scores:
        return focus[0] if focus else "exercise_start"

    # Filter to focus categories if specified
    if focus:
        focused = {k: v for k, v in scores.items() if any(f in k for f in focus)}
        if focused:
            scores = focused

    # Return lowest scoring category
    return min(scores, key=scores.get)


def run_command(cmd: list[str], description: str) -> tuple[int, str]:
    """Run a command and return (returncode, output)."""
    print(f"\n▶ {description}")
    print(f"  $ {' '.join(cmd)}")

    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(Path(__file__).parent))
    if result.returncode != 0:
        print(f"  ❌ Failed (exit {result.returncode})")
        if result.stderr:
            print(f"  stderr: {result.stderr[:500]}")
    return result.returncode, result.stdout + result.stderr


def extract_wtca(output: str) -> float | None:
    """Extract WTCA score from eval output."""
    for line in output.split("\n"):
        if line.startswith("WTCA:"):
            try:
                return float(line.split(":")[1].strip())
            except ValueError:
                pass
    return None


def extract_category_scores(output: str) -> dict:
    """Extract per-category accuracy from eval output."""
    scores = {}
    for line in output.split("\n"):
        for cat in CATEGORIES:
            if cat in line and "%" in line:
                # Parse "✅ food_logging        280    300   93.3%"
                parts = line.split()
                for p in parts:
                    if p.endswith("%"):
                        try:
                            scores[cat] = float(p.rstrip("%"))
                        except ValueError:
                            pass
                        break
    return scores


def log_result(wtca: float, category_scores: dict, status: str, description: str):
    """Append a result to results.tsv."""
    results_path = Path(RESULTS_FILE)
    write_header = not results_path.exists()

    # Get git commit
    try:
        commit = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True
        ).stdout.strip()
    except Exception:
        commit = "unknown"

    fields = ["timestamp", "commit", "wtca"] + CATEGORIES + ["status", "description"]

    with open(results_path, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
        if write_header:
            writer.writeheader()

        row = {
            "timestamp": datetime.now().isoformat(),
            "commit": commit,
            "wtca": f"{wtca:.1f}",
            "status": status,
            "description": description,
        }
        for cat in CATEGORIES:
            row[cat] = f"{category_scores.get(cat, 0):.1f}"

        writer.writerow(row)
    print(f"  📝 Logged to {RESULTS_FILE}: {status} (WTCA={wtca:.1f})")


def run_cycle(config_path: str, cycle_num: int, steering: dict, last_result: dict | None, data_only: bool = False) -> dict | None:
    """Run one improvement cycle. Returns new result or None if discarded."""
    print(f"\n{'='*60}")
    print(f"CYCLE {cycle_num}")
    print(f"{'='*60}")

    # 1. Find weakest category
    weakest = find_weakest_category(last_result, steering.get("focus", []))
    budget = steering.get("data_budget", 200)
    print(f"  Focus: {weakest} ({budget} new examples)")

    # 2. Generate targeted data
    rc, out = run_command(
        [sys.executable, "data/generate_data.py",
         "--category", weakest, "--count", str(budget),
         "--output", f"data/generated_{weakest}.jsonl"],
        f"Generating {budget} {weakest} examples"
    )
    if rc != 0:
        print(f"  ❌ Data generation failed, skipping cycle")
        return None

    # 3. Merge into main training set and validate
    # Append new data to all_generated.jsonl
    generated_file = Path(f"data/generated_{weakest}.jsonl")
    all_file = Path("data/all_generated.jsonl")
    if generated_file.exists():
        with open(all_file, "a") as out_f:
            out_f.write(generated_file.read_text())
        generated_file.unlink()

    # Re-validate and split
    rc, out = run_command(
        [sys.executable, "data/validate_data.py", "data/all_generated.jsonl"],
        "Validating and splitting data"
    )
    if rc != 0:
        print(f"  ❌ Validation failed")
        return None

    if data_only:
        print(f"  ℹ️  Data-only mode, skipping training")
        return None

    # 4. Train
    rc, out = run_command(
        [sys.executable, "train.py", "--config", config_path, "--data", "data/train.jsonl"],
        "Fine-tuning"
    )
    if rc != 0:
        print(f"  ❌ Training failed")
        return None

    # 5. Eval
    # Find latest model output
    config = yaml.safe_load(open(config_path))
    model_name = config["model_id"].split("/")[-1]
    latest = Path(f"output/{model_name}/latest/final")
    if not latest.exists():
        print(f"  ❌ Model output not found: {latest}")
        return None

    rc, eval_out = run_command(
        [sys.executable, "eval.py", "--model", str(latest), "--data", "data/eval.jsonl",
         "--chat-template", config.get("chat_template", "chatml")],
        "Evaluating"
    )

    wtca = extract_wtca(eval_out)
    cat_scores = extract_category_scores(eval_out)

    if wtca is None:
        print(f"  ❌ Could not parse WTCA from eval output")
        return None

    # 6. Compare with last result
    last_wtca = float(last_result.get("wtca", 0)) if last_result else 0

    if wtca > last_wtca:
        print(f"\n  ✅ IMPROVED: WTCA {last_wtca:.1f} → {wtca:.1f} (+{wtca - last_wtca:.1f})")
        log_result(wtca, cat_scores, "keep", f"cycle {cycle_num}: focused on {weakest}")
        return {"wtca": wtca, "scores": cat_scores, "status": "keep"}
    else:
        print(f"\n  ❌ NO IMPROVEMENT: WTCA {last_wtca:.1f} → {wtca:.1f}")
        log_result(wtca, cat_scores, "discard", f"cycle {cycle_num}: focused on {weakest}, no gain")
        return {"wtca": wtca, "scores": cat_scores, "status": "discard"}


def main():
    parser = argparse.ArgumentParser(description="Continuous improvement loop")
    parser.add_argument("--config", type=str, required=True, help="Model config YAML")
    parser.add_argument("--cycles", type=int, default=0, help="Max cycles (0=infinite)")
    parser.add_argument("--data-only", action="store_true", help="Only generate data, don't train")
    args = parser.parse_args()

    print(f"{'='*60}")
    print(f"DRIFT FINE-TUNE LOOP")
    print(f"Config: {args.config}")
    print(f"Max cycles: {'∞' if args.cycles == 0 else args.cycles}")
    print(f"{'='*60}")

    cycle = 0
    keeps = 0

    while True:
        cycle += 1
        if args.cycles > 0 and cycle > args.cycles:
            print(f"\nReached max cycles ({args.cycles}), stopping")
            break

        # Re-read steering every cycle
        steering = read_steering()
        if steering.get("override", "").upper() == "STOP":
            print(f"\nSteering says STOP, exiting")
            break

        last = get_last_result()
        result = run_cycle(args.config, cycle, steering, last, args.data_only)

        if result and result["status"] == "keep":
            keeps += 1
            # Deep train every 5 keeps
            if keeps % 5 == 0:
                print(f"\n{'='*60}")
                print(f"DEEP TRAIN (every 5 keeps, this is keep #{keeps})")
                print(f"{'='*60}")
                # Run with more epochs, lower LR (modify config in-memory)
                run_command(
                    [sys.executable, "train.py", "--config", args.config,
                     "--data", "data/train.jsonl"],
                    "Deep training (same config, cumulative data)"
                )

        print(f"\nCycle {cycle} complete. Keeps: {keeps}")
        time.sleep(2)  # Brief pause between cycles

    print(f"\n{'='*60}")
    print(f"LOOP COMPLETE: {cycle} cycles, {keeps} keeps")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
