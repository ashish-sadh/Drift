#!/usr/bin/env python3
"""
Bulk piece-size enrichment for foods.json.

Iterates foods where piece_size_g / cup_size_g / tbsp_size_g are null,
queries USDA FoodData Central first (Foundation + SR-Legacy datasets),
falls back to OpenFoodFacts search for branded/regional foods, and
writes matched values back to foods.json.

Unmatched foods are logged to scripts/enrich-unmatched.csv for nutritionist review.

Usage:
    # Register a free key at https://fdc.nal.usda.gov/api-guide.html (instant)
    USDA_API_KEY=YOUR_KEY python3 scripts/enrich-piece-sizes.py

    # Or use DEMO_KEY (30 req/hr — slow, for testing only)
    python3 scripts/enrich-piece-sizes.py

    # Dry run — print what would be changed without writing
    python3 scripts/enrich-piece-sizes.py --dry-run

    # Limit to N foods (for testing)
    python3 scripts/enrich-piece-sizes.py --limit 50
"""

import argparse
import csv
import difflib
import json
import os
import re
import sys
import time
import urllib.request
import urllib.parse
from typing import Optional

FOODS_JSON = os.path.join(os.path.dirname(__file__), "..", "DriftCore", "Sources", "DriftCore", "Resources", "foods.json")
UNMATCHED_CSV = os.path.join(os.path.dirname(__file__), "enrich-unmatched.csv")

USDA_API_KEY = os.environ.get("USDA_API_KEY", "DEMO_KEY")

# Plausible weight ranges per unit (outside = reject as bogus USDA entry)
PIECE_MIN_G, PIECE_MAX_G = 3.0, 800.0
CUP_MIN_G, CUP_MAX_G = 30.0, 600.0
TBSP_MIN_G, TBSP_MAX_G = 3.0, 60.0

# USDA rate: DEMO_KEY ~30 req/hr (1 per 2min), registered key ~3600 req/hr.
USDA_DELAY = 2.0 if USDA_API_KEY == "DEMO_KEY" else 0.4
OFF_DELAY = 0.5   # OpenFoodFacts asks for politeness

# Minimum name similarity to accept a USDA result as a match (0-1).
NAME_SIMILARITY_THRESHOLD = 0.40

# Categories where "piece" almost never applies; skip expensive USDA lookup for piece.
NO_PIECE_CATEGORIES = {
    "Beverages", "Oils & Fats", "Condiments & Sauces",
    "Supplements & Shakes", "Powders & Mixes",
}

# Words in food names that signal a bowl/serving, not a countable piece.
BOWL_WORDS = {"curry", "dal", "daal", "sabzi", "sabji", "gravy", "soup",
              "stew", "rice", "upma", "poha", "khichdi", "porridge",
              "oatmeal", "salad", "smoothie", "shake", "juice", "milk",
              "pulao", "biryani", "kheer", "halwa", "payasam"}


def _normalize(name: str) -> str:
    """Lowercase, strip parentheticals and common noise for matching."""
    name = name.lower()
    name = re.sub(r'\(.*?\)', '', name)           # remove (1 cup), (cooked), etc.
    name = re.sub(r',.*', '', name)               # take only the primary noun
    name = re.sub(r'\b(raw|cooked|fresh|frozen|dried|canned|whole|sliced|diced|chopped|boiled|steamed|fried|grilled|roasted|baked|plain|unsalted|salted|sweetened|unsweetened)\b', '', name)
    name = re.sub(r'\s+', ' ', name).strip()
    return name


def _name_similarity(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, _normalize(a), _normalize(b)).ratio()


def _extract_usda_weights(portions: list) -> tuple:
    """
    Mirror of USDAFoodService.extractUnitWeights in Swift.
    Returns (piece_g, cup_g, tbsp_g) — None when no plausible match.
    """
    def weight_for(predicate):
        for p in portions:
            mod = str(p.get("modifier", "")).lower()
            amount = float(p.get("amount", 1) or 1)
            g = float(p.get("gramWeight", 0) or 0)
            if amount > 0 and g > 0 and predicate(mod):
                return g / amount
        return None

    piece = weight_for(lambda m: (
        "medium" in m or m == "each" or " each" in m or
        m.startswith("1 ") or "whole" in m or "berry" in m or
        "large" in m or "small" in m or "extra large" in m
    ))
    cup = weight_for(lambda m: "cup" in m)
    tbsp = weight_for(lambda m: "tbsp" in m or "tablespoon" in m)
    return piece, cup, tbsp


def _clamp_or_none(value: Optional[float], lo: float, hi: float) -> Optional[float]:
    if value is None:
        return None
    return round(value, 1) if lo <= value <= hi else None


def query_usda(food_name: str) -> dict:
    """Search USDA and return best-match piece/cup/tbsp weights."""
    query = _normalize(food_name)
    encoded = urllib.parse.quote(query)
    url = (
        f"https://api.nal.usda.gov/fdc/v1/foods/search"
        f"?query={encoded}&pageSize=8&dataType=Foundation,SR%20Legacy"
        f"&api_key={USDA_API_KEY}"
    )
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Drift-enrich-piece-sizes/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        print(f"    [USDA error] {e}", file=sys.stderr)
        return {}

    foods = data.get("foods", [])
    if not foods:
        return {}

    # Pick the result with the highest name similarity.
    best_food = max(foods, key=lambda f: _name_similarity(food_name, f.get("description", "")))
    best_sim = _name_similarity(food_name, best_food.get("description", ""))
    if best_sim < NAME_SIMILARITY_THRESHOLD:
        return {}

    portions = best_food.get("foodPortions", [])
    piece_raw, cup_raw, tbsp_raw = _extract_usda_weights(portions)

    return {
        "source": "usda",
        "matched_name": best_food.get("description", ""),
        "similarity": round(best_sim, 2),
        "piece_size_g": _clamp_or_none(piece_raw, PIECE_MIN_G, PIECE_MAX_G),
        "cup_size_g": _clamp_or_none(cup_raw, CUP_MIN_G, CUP_MAX_G),
        "tbsp_size_g": _clamp_or_none(tbsp_raw, TBSP_MIN_G, TBSP_MAX_G),
    }


def query_off(food_name: str) -> dict:
    """Search OpenFoodFacts for serving_size data."""
    encoded = urllib.parse.quote(food_name)
    url = (
        f"https://world.openfoodfacts.org/cgi/search.pl"
        f"?search_terms={encoded}&json=1&page_size=5"
        f"&fields=product_name,serving_size,nutriments"
    )
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Drift-enrich-piece-sizes/1.0 (contact: ashishsadh)"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        print(f"    [OFF error] {e}", file=sys.stderr)
        return {}

    products = data.get("products", [])
    if not products:
        return {}

    best = max(products, key=lambda p: _name_similarity(food_name, p.get("product_name", "")))
    best_sim = _name_similarity(food_name, best.get("product_name", ""))
    if best_sim < NAME_SIMILARITY_THRESHOLD:
        return {}

    serving_str = best.get("serving_size", "") or ""
    piece_g = None

    # Parse patterns like "1 piece (30g)", "3 pieces (85g)", "30g"
    m = re.search(r'(\d+)\s*(?:piece|pc|unit|bar|cookie|cracker|biscuit)s?\s*\((\d+(?:\.\d+)?)\s*g\)', serving_str, re.I)
    if m:
        count = int(m.group(1))
        total_g = float(m.group(2))
        if count > 0:
            piece_g = round(total_g / count, 1)

    if piece_g is None:
        # Plain "30g" with no piece count
        m = re.search(r'^(\d+(?:\.\d+)?)\s*g$', serving_str.strip(), re.I)
        if m:
            piece_g = float(m.group(1))

    piece_g = _clamp_or_none(piece_g, PIECE_MIN_G, PIECE_MAX_G)

    return {
        "source": "off",
        "matched_name": best.get("product_name", ""),
        "similarity": round(best_sim, 2),
        "piece_size_g": piece_g,
        "cup_size_g": None,
        "tbsp_size_g": None,
    }


def _has_bowl_word(name: str) -> bool:
    words = set(name.lower().split())
    return bool(words & BOWL_WORDS)


def _needs_any_enrichment(food: dict) -> bool:
    """True if any of the three unit fields is missing."""
    return (
        food.get("piece_size_g") is None or
        food.get("cup_size_g") is None or
        food.get("tbsp_size_g") is None
    )


def enrich(dry_run: bool, limit: Optional[int]) -> None:
    with open(FOODS_JSON) as f:
        foods = json.load(f)

    to_enrich = [i for i, food in enumerate(foods) if _needs_any_enrichment(food)]
    print(f"Foods needing enrichment: {len(to_enrich)} of {len(foods)} total")
    print(f"USDA key: {'registered (' + USDA_API_KEY[:6] + '...)' if USDA_API_KEY != 'DEMO_KEY' else 'DEMO_KEY (slow — register a free key at fdc.nal.usda.gov)'}")

    if limit:
        to_enrich = to_enrich[:limit]
        print(f"Limiting to first {limit} foods")

    unmatched = []
    usda_hits = 0
    off_hits = 0
    skipped_bowl = 0
    total = len(to_enrich)

    for step, idx in enumerate(to_enrich, 1):
        food = foods[idx]
        name = food["name"]
        category = food.get("category", "")
        missing = []
        if food.get("piece_size_g") is None:
            missing.append("piece")
        if food.get("cup_size_g") is None:
            missing.append("cup")
        if food.get("tbsp_size_g") is None:
            missing.append("tbsp")

        print(f"[{step}/{total}] {name} (missing: {', '.join(missing)})")

        # Determine which lookups to do
        need_piece = food.get("piece_size_g") is None
        need_cup = food.get("cup_size_g") is None
        need_tbsp = food.get("tbsp_size_g") is None

        is_bowl = _has_bowl_word(name) or category in NO_PIECE_CATEGORIES
        if is_bowl and need_piece:
            print(f"    → skip piece lookup (bowl/serving food)")
            skipped_bowl += 1
            need_piece = False  # still try cup/tbsp for these

        # USDA lookup
        result = {}
        if need_piece or need_cup or need_tbsp:
            time.sleep(USDA_DELAY)
            result = query_usda(name)
            if result:
                print(f"    USDA match: {result['matched_name']} (sim={result['similarity']})")
                usda_hits += 1
            else:
                print(f"    USDA: no match")

        # OFF fallback for piece only (OFF is branded; not great for cups/tbsp)
        if need_piece and (not result or result.get("piece_size_g") is None):
            time.sleep(OFF_DELAY)
            off_result = query_off(name)
            if off_result and off_result.get("piece_size_g"):
                print(f"    OFF match: {off_result['matched_name']} (sim={off_result['similarity']})")
                if not result:
                    result = off_result
                    off_hits += 1
                else:
                    result["piece_size_g"] = off_result["piece_size_g"]
                    result["source"] = "usda+off"

        # Apply enrichment
        got_anything = False
        if need_piece and result.get("piece_size_g") is not None:
            if not dry_run:
                foods[idx]["piece_size_g"] = result["piece_size_g"]
            print(f"    ✓ piece_size_g = {result['piece_size_g']}g")
            got_anything = True
        if need_cup and result.get("cup_size_g") is not None:
            if not dry_run:
                foods[idx]["cup_size_g"] = result["cup_size_g"]
            print(f"    ✓ cup_size_g = {result['cup_size_g']}g")
            got_anything = True
        if need_tbsp and result.get("tbsp_size_g") is not None:
            if not dry_run:
                foods[idx]["tbsp_size_g"] = result["tbsp_size_g"]
            print(f"    ✓ tbsp_size_g = {result['tbsp_size_g']}g")
            got_anything = True

        if not got_anything:
            reason = "bowl_food" if is_bowl else ("usda_no_portions" if result else "no_match")
            unmatched.append({
                "name": name,
                "category": category,
                "serving_size": food.get("serving_size"),
                "reason": reason,
                "usda_matched": result.get("matched_name", "") if result else "",
                "usda_similarity": result.get("similarity", "") if result else "",
            })
            print(f"    ✗ unmatched ({reason})")

        # Save progress every 100 foods
        if not dry_run and step % 100 == 0:
            with open(FOODS_JSON, "w") as f:
                json.dump(foods, f, indent=2, ensure_ascii=False)
            print(f"  [checkpoint] saved {step}/{total}")

    # Final save
    if not dry_run:
        with open(FOODS_JSON, "w") as f:
            json.dump(foods, f, indent=2, ensure_ascii=False)

    # Write unmatched CSV
    if not dry_run and unmatched:
        with open(UNMATCHED_CSV, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["name", "category", "serving_size", "reason", "usda_matched", "usda_similarity"])
            writer.writeheader()
            writer.writerows(unmatched)
        print(f"\nUnmatched foods written to: {UNMATCHED_CSV}")

    print(f"\n=== Summary ===")
    print(f"Processed: {total}")
    print(f"USDA hits: {usda_hits}")
    print(f"OFF hits: {off_hits}")
    print(f"Skipped (bowl/category): {skipped_bowl}")
    print(f"Unmatched: {len(unmatched)}")
    if dry_run:
        print("(dry run — foods.json not modified)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Bulk piece-size enrichment for foods.json")
    parser.add_argument("--dry-run", action="store_true", help="Print what would change without writing")
    parser.add_argument("--limit", type=int, default=None, help="Process only N foods (for testing)")
    args = parser.parse_args()
    enrich(dry_run=args.dry_run, limit=args.limit)
