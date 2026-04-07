#!/usr/bin/env python3
"""
Tool-calling accuracy evaluator for Drift fine-tuned models.
Supports HuggingFace checkpoints and GGUF models.

Usage:
    python eval.py --model output/latest/final --data data/eval.jsonl
    python eval.py --gguf path/to/model.gguf --data data/eval.jsonl
    python eval.py --model output/latest/final --data data/eval.jsonl --baseline  # unfinetuned comparison
"""

import argparse
import json
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

VALID_TOOLS = {"log_food", "food_info", "log_weight", "weight_info",
               "start_workout", "exercise_info", "sleep_recovery", "supplements"}

# Categories that should NOT produce a tool call
NO_TOOL_CATEGORIES = {"no_tool", "hard_negatives"}


def parse_tool_call(response: str) -> dict | None:
    """Extract tool call JSON from model response. Mirrors ToolSchema.swift:142-157."""
    # Find first { to last }
    start = response.find("{")
    end = response.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return None
    try:
        obj = json.loads(response[start:end + 1])
        if "tool" in obj and isinstance(obj["tool"], str):
            return obj
    except json.JSONDecodeError:
        pass
    return None


class ModelInference:
    """Abstract interface for model inference."""

    def respond(self, system: str, user: str) -> str:
        raise NotImplementedError


class HFInference(ModelInference):
    """Inference using HuggingFace transformers."""

    def __init__(self, model_path: str, chat_template: str = "chatml"):
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer
        from peft import PeftModel

        self.chat_template = chat_template
        # Resolve to absolute path for local checkpoints
        abs_path = str(Path(model_path).resolve())

        # Check if this is a LoRA adapter or merged model
        adapter_config = Path(abs_path) / "adapter_config.json"
        if adapter_config.exists():
            with open(adapter_config) as f:
                cfg = json.load(f)
            base_model = cfg.get("base_model_name_or_path", "")
            print(f"Loading base model: {base_model}")
            self.tokenizer = AutoTokenizer.from_pretrained(base_model, trust_remote_code=True)
            base = AutoModelForCausalLM.from_pretrained(base_model, torch_dtype=torch.float32, trust_remote_code=True)
            self.model = PeftModel.from_pretrained(base, abs_path)
        else:
            self.tokenizer = AutoTokenizer.from_pretrained(abs_path, trust_remote_code=True)
            self.model = AutoModelForCausalLM.from_pretrained(abs_path, torch_dtype=torch.float32, trust_remote_code=True)

        if torch.backends.mps.is_available():
            self.model = self.model.to("mps")
        self.model.eval()

    def respond(self, system: str, user: str) -> str:
        import torch

        if self.chat_template == "gemma":
            prompt = f"<start_of_turn>user\n{system}\n\n{user}<end_of_turn>\n<start_of_turn>model\n"
        else:
            prompt = f"<|im_start|>system\n{system}<|im_end|>\n<|im_start|>user\n{user}<|im_end|>\n<|im_start|>assistant\n"

        inputs = self.tokenizer(prompt, return_tensors="pt")
        if torch.backends.mps.is_available():
            inputs = {k: v.to("mps") for k, v in inputs.items()}

        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_new_tokens=256,
                temperature=0.4,
                top_p=0.9,
                do_sample=True,
                pad_token_id=self.tokenizer.pad_token_id or self.tokenizer.eos_token_id,
            )

        generated = outputs[0][inputs["input_ids"].shape[1]:]
        return self.tokenizer.decode(generated, skip_special_tokens=True).strip()


class GGUFInference(ModelInference):
    """Inference using llama-cpp-python."""

    def __init__(self, gguf_path: str):
        from llama_cpp import Llama

        self.model = Llama(
            model_path=gguf_path,
            n_ctx=2048,
            n_threads=6,
            verbose=False,
        )

    def respond(self, system: str, user: str) -> str:
        prompt = f"<|im_start|>system\n{system}<|im_end|>\n<|im_start|>user\n{user}<|im_end|>\n<|im_start|>assistant\n"

        output = self.model(
            prompt,
            max_tokens=256,
            temperature=0.4,
            top_p=0.9,
            stop=["<|im_end|>", "<|im_start|>"],
        )

        return output["choices"][0]["text"].strip()


def evaluate(model: ModelInference, data_path: str) -> dict:
    """Run evaluation and return metrics."""
    examples = []
    with open(data_path) as f:
        for line in f:
            line = line.strip()
            if line:
                examples.append(json.loads(line))

    print(f"Evaluating {len(examples)} examples...\n")

    results = defaultdict(lambda: {"correct": 0, "total": 0, "json_valid": 0, "details": []})
    start_time = time.time()

    for i, ex in enumerate(examples):
        category = ex["category"]
        system = ex["system"]
        user = ex["user"]
        expected_assistant = ex["assistant"]

        # Run inference
        response = model.respond(system, user)
        actual_call = parse_tool_call(response)

        # Determine expected tool
        if category in NO_TOOL_CATEGORIES:
            expected_tool = None
            expected_call = None
        else:
            expected_call = json.loads(expected_assistant)
            expected_tool = expected_call["tool"]

        # Score: tool selection
        actual_tool = actual_call["tool"] if actual_call else None
        correct = actual_tool == expected_tool

        # Score: JSON validity (for tool-calling categories)
        json_valid = False
        if category not in NO_TOOL_CATEGORIES:
            if actual_call and actual_call.get("tool") in VALID_TOOLS:
                json_valid = True

        results[category]["total"] += 1
        if correct:
            results[category]["correct"] += 1
        if json_valid:
            results[category]["json_valid"] += 1

        # Store detail for debugging
        query = ex.get("query", user[-80:])
        if not correct:
            results[category]["details"].append({
                "query": query,
                "expected": expected_tool,
                "actual": actual_tool,
                "response": response[:120],
            })

        # Progress
        if (i + 1) % 10 == 0:
            elapsed = time.time() - start_time
            rate = (i + 1) / elapsed
            remaining = (len(examples) - i - 1) / rate if rate > 0 else 0
            print(f"  [{i+1}/{len(examples)}] {rate:.1f} ex/s, ~{remaining:.0f}s remaining")

    elapsed = time.time() - start_time
    return dict(results), elapsed


def compute_wtca(results: dict) -> float:
    """Compute Weighted Tool-Call Accuracy. Weak categories weighted higher."""
    # Weights: inversely proportional to baseline performance
    WEIGHTS = {
        "food_logging": 1.0,     # already strong
        "food_questions": 2.0,   # weak
        "weight_logging": 2.5,   # very weak
        "weight_questions": 2.5, # very weak
        "exercise_start": 3.0,   # weakest
        "exercise_questions": 3.0,
        "sleep_recovery": 1.5,
        "supplements": 1.5,
        "no_tool": 2.0,          # important for UX
        "hard_negatives": 2.0,
    }

    weighted_sum = 0
    weight_total = 0

    for cat, metrics in results.items():
        if metrics["total"] == 0:
            continue
        accuracy = metrics["correct"] / metrics["total"]
        w = WEIGHTS.get(cat, 1.0)
        weighted_sum += accuracy * w
        weight_total += w

    return weighted_sum / weight_total if weight_total > 0 else 0


def print_report(results: dict, elapsed: float):
    """Print evaluation report."""
    print(f"\n{'='*70}")
    print(f"EVAL RESULTS ({elapsed:.1f}s)")
    print(f"{'='*70}")
    print(f"{'Category':25s} {'Correct':>8s} {'Total':>6s} {'Acc':>7s} {'JSON%':>7s}")
    print(f"{'-'*70}")

    total_correct = 0
    total_all = 0

    for cat in sorted(results.keys()):
        m = results[cat]
        total_correct += m["correct"]
        total_all += m["total"]
        acc = m["correct"] / m["total"] * 100 if m["total"] else 0
        json_pct = m["json_valid"] / m["total"] * 100 if m["total"] else 0
        marker = "✅" if acc >= 70 else "⚠️ " if acc >= 50 else "❌"
        json_col = f"{json_pct:.0f}%" if cat not in NO_TOOL_CATEGORIES else "n/a"
        print(f"{marker} {cat:23s} {m['correct']:>6d} {m['total']:>6d} {acc:>6.1f}% {json_col:>6s}")

    overall = total_correct / total_all * 100 if total_all else 0
    wtca = compute_wtca(results) * 100
    print(f"{'-'*70}")
    print(f"   {'Overall':23s} {total_correct:>6d} {total_all:>6d} {overall:>6.1f}%")
    print(f"   {'WTCA (weighted)':23s} {'':>6s} {'':>6s} {wtca:>6.1f}%")
    print(f"{'='*70}")
    print(f"WTCA: {wtca:.1f}")  # machine-parseable line for loop.py

    # Print failures for debugging
    any_failures = False
    for cat in sorted(results.keys()):
        failures = results[cat]["details"]
        if failures:
            if not any_failures:
                print(f"\n{'='*70}")
                print("FAILURES (first 5 per category)")
                print(f"{'='*70}")
                any_failures = True
            print(f"\n{cat}:")
            for f in failures[:5]:
                print(f"  ❌ '{f['query']}' → expected={f['expected']}, got={f['actual']}")
                print(f"     response: {f['response']}")


def main():
    parser = argparse.ArgumentParser(description="Evaluate tool-calling accuracy")
    parser.add_argument("--model", type=str, help="HuggingFace model/checkpoint path")
    parser.add_argument("--gguf", type=str, help="GGUF model path")
    parser.add_argument("--data", type=str, required=True, help="Eval data JSONL")
    parser.add_argument("--chat-template", type=str, default="chatml", choices=["chatml", "gemma"])
    parser.add_argument("--limit", type=int, default=None, help="Limit number of examples")
    args = parser.parse_args()

    if not args.model and not args.gguf:
        print("Specify --model <path> or --gguf <path>")
        sys.exit(1)

    # Load model
    if args.gguf:
        print(f"Loading GGUF: {args.gguf}")
        model = GGUFInference(args.gguf)
    else:
        print(f"Loading model: {args.model}")
        model = HFInference(args.model, args.chat_template)

    # Run eval
    results, elapsed = evaluate(model, args.data)
    print_report(results, elapsed)


if __name__ == "__main__":
    main()
