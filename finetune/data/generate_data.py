#!/usr/bin/env python3
"""
Synthetic training data generator using Claude API.
Generates ChatML-formatted tool-calling examples for Drift's on-device SLM.

Usage:
    python data/generate_data.py --category food_logging --count 50
    python data/generate_data.py --all              # generate all categories
    python data/generate_data.py --all --count 20   # quick test run (20 per category)
"""

import argparse
import json
import os
import sys
from pathlib import Path

# Load .env file if present
env_path = Path(__file__).parent.parent / ".env"
if env_path.exists():
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, val = line.split("=", 1)
            os.environ.setdefault(key.strip(), val.strip())

import anthropic

from templates import (
    CATEGORIES,
    TOOLS,
    format_tool_lines,
    get_tools_for_screen,
    random_context,
    system_prompt,
)

client = anthropic.Anthropic()

# Seed examples from LLMToolCallingEval.swift for each category
SEED_EXAMPLES = {
    "food_logging": [
        ("I had 2 eggs", {"tool": "log_food", "params": {"name": "eggs", "amount": "2"}}),
        ("log chicken breast", {"tool": "log_food", "params": {"name": "chicken breast", "amount": "1"}}),
        ("ate a banana for lunch", {"tool": "log_food", "params": {"name": "banana", "amount": "1"}}),
        ("had dal and rice", {"tool": "log_food", "params": {"name": "dal and rice", "amount": "1"}}),
        ("I just had a samosa", {"tool": "log_food", "params": {"name": "samosa", "amount": "1"}}),
        ("ate 3 rotis for dinner", {"tool": "log_food", "params": {"name": "rotis", "amount": "3"}}),
        ("log paneer butter masala", {"tool": "log_food", "params": {"name": "paneer butter masala", "amount": "1"}}),
        ("had biryani for lunch", {"tool": "log_food", "params": {"name": "biryani", "amount": "1"}}),
        ("drank a glass of milk", {"tool": "log_food", "params": {"name": "milk", "amount": "1"}}),
    ],
    "food_questions": [
        ("calories left?", {"tool": "food_info", "params": {}}),
        ("how much protein in banana", {"tool": "food_info", "params": {"query": "protein in banana"}}),
        ("what should I eat for dinner", {"tool": "food_info", "params": {"query": "dinner suggestions"}}),
        ("calories in a samosa", {"tool": "food_info", "params": {"query": "samosa calories"}}),
        ("suggest something high protein", {"tool": "food_info", "params": {"query": "high protein foods"}}),
        ("am I eating too much", {"tool": "food_info", "params": {}}),
        ("what did I eat today", {"tool": "food_info", "params": {}}),
    ],
    "weight_logging": [
        ("I weigh 165 lbs", {"tool": "log_weight", "params": {"value": "165", "unit": "lbs"}}),
        ("my weight is 75 kg", {"tool": "log_weight", "params": {"value": "75", "unit": "kg"}}),
        ("scale says 170 today", {"tool": "log_weight", "params": {"value": "170", "unit": "lbs"}}),
        ("weighed in at 80 kg", {"tool": "log_weight", "params": {"value": "80", "unit": "kg"}}),
    ],
    "weight_questions": [
        ("how's my weight trend", {"tool": "weight_info", "params": {}}),
        ("am I on track to reach my goal", {"tool": "weight_info", "params": {}}),
        ("how much have I lost this month", {"tool": "weight_info", "params": {}}),
        ("what's my body fat", {"tool": "weight_info", "params": {}}),
        ("what's my BMI", {"tool": "weight_info", "params": {}}),
        ("am I losing weight", {"tool": "weight_info", "params": {}}),
    ],
    "exercise_start": [
        ("start push day", {"tool": "start_workout", "params": {"name": "push day"}}),
        ("start chest workout", {"tool": "start_workout", "params": {"name": "chest"}}),
        ("I want to do legs today", {"tool": "start_workout", "params": {"name": "legs"}}),
        ("build me a back workout", {"tool": "start_workout", "params": {"name": "back"}}),
        ("start leg day", {"tool": "start_workout", "params": {"name": "legs"}}),
    ],
    "exercise_questions": [
        ("what should I train today", {"tool": "exercise_info", "params": {}}),
        ("what muscle haven't I trained", {"tool": "exercise_info", "params": {}}),
        ("am I making progress on bench", {"tool": "exercise_info", "params": {"exercise": "bench press"}}),
        ("how's my training volume", {"tool": "exercise_info", "params": {}}),
        ("what did I train last", {"tool": "exercise_info", "params": {}}),
    ],
    "sleep_recovery": [
        ("how'd I sleep last night", {"tool": "sleep_recovery", "params": {}}),
        ("what's my recovery score", {"tool": "sleep_recovery", "params": {}}),
        ("should I train today or rest", {"tool": "sleep_recovery", "params": {}}),
        ("I'm feeling tired", {"tool": "sleep_recovery", "params": {}}),
        ("what's my HRV", {"tool": "sleep_recovery", "params": {}}),
    ],
    "supplements": [
        ("did I take my vitamins", {"tool": "supplements", "params": {}}),
        ("what supplements should I take", {"tool": "supplements", "params": {}}),
        ("have I had my creatine today", {"tool": "supplements", "params": {}}),
    ],
    "no_tool": [
        ("thanks!", None),
        ("hello", None),
        ("ok got it", None),
        ("what can you do", None),
        ("you're helpful", None),
        ("nice", None),
    ],
    "hard_negatives": [
        ("how much does chicken weigh", None),  # NOT log_weight
        ("I need to exercise more discipline", None),  # NOT exercise tools
        ("the food was heavy", None),  # NOT log_weight
        ("I'm weighing my options", None),  # NOT log_weight
        ("that workout was killer", None),  # NOT start_workout (past tense)
    ],
}


def build_generation_prompt(category: str, count: int) -> str:
    """Build the Claude API prompt for generating training examples."""
    cat_info = CATEGORIES[category]
    tool = cat_info["tool"]
    screen = cat_info["screen"]
    seeds = SEED_EXAMPLES.get(category, [])

    tools_text = format_tool_lines(get_tools_for_screen(screen))
    sys_prompt = system_prompt(screen)

    # Format seed examples
    seed_lines = []
    for query, response in seeds:
        if response is None:
            seed_lines.append(f'  User: "{query}" → Assistant: friendly natural response (NO tool call)')
        else:
            seed_lines.append(f'  User: "{query}" → Assistant: {json.dumps(response)}')

    seed_text = "\n".join(seed_lines)

    if category == "hard_negatives":
        return f"""Generate {count} HARD NEGATIVE training examples for a health tracking AI assistant.

These are TRICKY queries that might LOOK like they need a tool call but should NOT trigger one.
The assistant should respond naturally without calling any tool.

Tool schemas available:
{tools_text}

Categories of hard negatives to generate:
- Food words in non-food context ("chicken weighs 200g" — asking about raw weight, NOT logging body weight)
- Exercise words in non-exercise context ("I need to exercise more caution")
- Weight words in non-weight context ("I'm weighing my options", "heavy workload")
- Past tense that doesn't need action ("that workout was great" — commenting, not starting)
- General health questions ("is keto good", "what is BMI" — educational, not tracking)
- Ambiguous but should be chat ("food for thought", "what's cooking")

Seed examples:
{seed_text}

For EACH example output a JSON object on its own line:
{{"user_query": "the user message", "assistant_response": "friendly natural language response", "category": "hard_negatives", "negative_for": "which tool it could be confused with"}}

Requirements:
- Diverse phrasing styles (casual, formal, slang, shorthand)
- Mix of tricky patterns
- The assistant response should be helpful and natural (1-2 sentences)
- Output ONLY the JSON lines, nothing else"""

    if category == "no_tool":
        return f"""Generate {count} CONVERSATIONAL training examples for a health tracking AI assistant.

These are messages where the user is chatting, greeting, thanking, or asking general questions.
The assistant should respond naturally WITHOUT calling any tool.

Seed examples:
{seed_text}

Categories to cover:
- Greetings ("hey", "hi there", "good morning")
- Thanks/appreciation ("thanks!", "that was helpful", "perfect")
- Acknowledgments ("ok", "got it", "cool", "nice")
- General questions ("what can you do", "how do you work")
- Casual chat ("how are you", "what's up")
- Compliments ("you're helpful", "great job")
- General health questions (educational, not tracking): "what is TDEE", "is creatine safe"

For EACH example output a JSON object on its own line:
{{"user_query": "the user message", "assistant_response": "friendly natural language response (1-2 sentences, no tool call)", "category": "no_tool"}}

Requirements:
- Diverse phrasing styles
- Responses should be brief, friendly, and helpful
- NEVER include a tool call JSON in the assistant response
- Output ONLY the JSON lines, nothing else"""

    # Tool-calling categories
    return f"""Generate {count} training examples for a health tracking AI assistant's "{category}" category.

The assistant must output ONLY a JSON tool call: {{"tool":"{tool}","params":{{...}}}}

System prompt the model sees:
{sys_prompt}

Seed examples:
{seed_text}

Tool being trained: {tool}
Tool description: {cat_info['description']}

Requirements:
- Each example needs a diverse USER QUERY and the correct TOOL CALL response
- Vary phrasing: casual ("had some eggs"), formal ("I'd like to log"), slang ("ate a ton of pizza"), shorthand ("log eggs 2")
- Vary content:
  * Food: Western, Indian, Asian, Mediterranean, Mexican, snacks, drinks, specific amounts, vague amounts ("a couple", "some"), fractions ("half"), meal hints ("for breakfast")
  * Weight: different values (100-250 lbs, 45-115 kg), different phrasings, with/without units
  * Exercise: muscle groups (chest, back, legs, arms, shoulders, core), workout types (push/pull/legs, upper/lower, full body), specific exercises
  * Sleep: tiredness, HRV, recovery, readiness, rest days
  * Supplements: vitamins, creatine, protein, fish oil, specific supplements
- Include edge cases: typos, mixed languages, compound foods ("dal chawal"), abbreviations
- Amount format variety: numbers (2), words (two, couple, few), fractions (1/2, half), decimals (1.5)
- Params must use string values: {{"name":"eggs","amount":"2"}} not {{"amount":2}}

For EACH example output a JSON object on its own line:
{{"user_query": "the user message", "tool_call": {{"tool":"{tool}","params":{{...}}}}, "category": "{category}"}}

Output ONLY the JSON lines, nothing else."""


def generate_batch(category: str, count: int) -> list[dict]:
    """Generate a batch of training examples via Claude API."""
    prompt = build_generation_prompt(category, count)

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        messages=[{"role": "user", "content": prompt}],
    )

    text = response.content[0].text.strip()
    examples = []
    for line in text.split("\n"):
        line = line.strip()
        if not line or not line.startswith("{"):
            continue
        try:
            obj = json.loads(line)
            examples.append(obj)
        except json.JSONDecodeError:
            print(f"  ⚠️  Skipping malformed line: {line[:80]}...")
            continue

    return examples


def convert_to_training_format(examples: list[dict], category: str, screen: str) -> list[dict]:
    """Convert generated examples to ChatML training format."""
    cat_info = CATEGORIES[category]
    sys = system_prompt(screen)
    training_data = []

    for ex in examples:
        query = ex.get("user_query", "")
        if not query:
            continue

        context = random_context()
        user_turn = f"Context about the user:\n{context}\n\nUser: {query}"

        # Build assistant response
        if category in ("no_tool", "hard_negatives"):
            assistant = ex.get("assistant_response", "")
            if not assistant:
                continue
        else:
            tool_call = ex.get("tool_call")
            if not tool_call:
                continue
            assistant = json.dumps(tool_call, separators=(",", ":"))

        training_data.append({
            "system": sys,
            "user": user_turn,
            "assistant": assistant,
            "category": category,
            "query": query,
        })

    return training_data


def main():
    parser = argparse.ArgumentParser(description="Generate synthetic training data")
    parser.add_argument("--category", type=str, help="Category to generate")
    parser.add_argument("--all", action="store_true", help="Generate all categories")
    parser.add_argument("--count", type=int, default=None, help="Override count per category")
    parser.add_argument("--output", type=str, default="data/all_generated.jsonl", help="Output file")
    parser.add_argument("--batch-size", type=int, default=50, help="Examples per API call")
    args = parser.parse_args()

    if not args.all and not args.category:
        print("Specify --category <name> or --all")
        sys.exit(1)

    categories = list(CATEGORIES.keys()) if args.all else [args.category]
    output_path = Path(args.output)
    all_training_data = []

    for cat in categories:
        if cat not in CATEGORIES:
            print(f"❌ Unknown category: {cat}")
            continue

        cat_info = CATEGORIES[cat]
        target_count = args.count or cat_info["count"]
        screen = cat_info["screen"]
        print(f"\n{'='*50}")
        print(f"Generating {cat}: {target_count} examples (screen={screen})")
        print(f"{'='*50}")

        generated = []
        remaining = target_count
        while remaining > 0:
            batch = min(args.batch_size, remaining)
            print(f"  Requesting batch of {batch}...")
            examples = generate_batch(cat, batch)
            print(f"  Got {len(examples)} examples")
            generated.extend(examples)
            remaining -= len(examples)
            if len(examples) < batch * 0.5:
                print(f"  ⚠️  Low yield, moving on")
                break

        training = convert_to_training_format(generated, cat, screen)
        all_training_data.extend(training)
        print(f"  ✅ {cat}: {len(training)} training examples")

    # Write output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        for item in all_training_data:
            f.write(json.dumps(item) + "\n")

    print(f"\n{'='*50}")
    print(f"Total: {len(all_training_data)} training examples → {output_path}")

    # Category breakdown
    from collections import Counter
    cats = Counter(item["category"] for item in all_training_data)
    for cat, count in sorted(cats.items()):
        print(f"  {cat}: {count}")


if __name__ == "__main__":
    main()
