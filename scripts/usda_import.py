#!/usr/bin/env python3
"""
USDA FoodData Central batch import — parses local Foundation Foods JSON dump.
Downloads the dump automatically if not present (~450 KB).

Usage:
    python3 scripts/usda_import.py [--dry-run]

Output: appends new entries to DriftCore/Sources/DriftCore/Resources/foods.json
"""
import json
import sys
import urllib.request
import zipfile
import io
from pathlib import Path

FOODS_JSON = Path(__file__).parent.parent / "DriftCore/Sources/DriftCore/Resources/foods.json"
FOUNDATION_URL = "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2024-10-31.zip"
CACHE_PATH = Path("/tmp/usda_foundation/foundationDownload.json")

DRY_RUN = "--dry-run" in sys.argv

# USDA nutrient IDs
NID = {
    "calories": 1008,
    "protein": 1003,
    "fat": 1004,
    "carbs": 1005,
    "fiber": 1079,
    "sodium": 1093,
    "sugar": 2000,
}

# USDA foodCategory → Drift category
CATEGORY_MAP = {
    "Baked Products": "Grains & Pasta",
    "Beef Products": "Proteins",
    "Beverages": "Beverages",
    "Cereal Grains and Pasta": "Grains & Cereals",
    "Dairy and Egg Products": "Dairy",
    "Fats and Oils": "Oils & Fats",
    "Finfish and Shellfish Products": "Seafood",
    "Fruits and Fruit Juices": "Fruits",
    "Legumes and Legume Products": "Proteins",
    "Nut and Seed Products": "Nuts & Seeds",
    "Pork Products": "Proteins",
    "Poultry Products": "Proteins",
    "Restaurant Foods": "Fast Food",
    "Sausages and Luncheon Meats": "Proteins",
    "Soups, Sauces, and Gravies": "Condiments",
    "Spices and Herbs": "Condiments",
    "Sweets": "Desserts",
    "Vegetables and Vegetable Products": "Vegetables",
}


def ensure_dump() -> Path:
    if CACHE_PATH.exists():
        return CACHE_PATH
    print("Downloading USDA Foundation Foods dump (~450 KB)...")
    with urllib.request.urlopen(FOUNDATION_URL, timeout=60) as resp:
        data = resp.read()
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        name = zf.namelist()[0]
        CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        CACHE_PATH.write_bytes(zf.read(name))
    print(f"Saved to {CACHE_PATH}")
    return CACHE_PATH


def nutrient_value(nutrients: list, *nids: int) -> float:
    """Return first non-zero value matching any of the given nutrient IDs (priority order)."""
    index: dict[int, float] = {}
    for n in nutrients:
        nid = n.get("nutrient", {}).get("id")
        if nid in nids:
            v = float(n.get("amount") or 0)
            if v and nid not in index:
                index[nid] = v
    for nid in nids:
        if nid in index:
            return round(index[nid], 2)
    return 0.0


def extract_unit_weights(portions: list) -> tuple:
    """Returns (piece_g, cup_g, tbsp_g) from USDA foodPortions array."""
    def weight(predicate):
        for p in portions:
            unit_name = (p.get("measureUnit") or {}).get("name", "").lower()
            modifier = (p.get("modifier") or "").lower()
            label = f"{unit_name} {modifier}".strip()
            amount = float(p.get("amount") or 1) or 1
            g = float(p.get("gramWeight") or 0)
            if g > 0 and predicate(label):
                return round(g / amount, 1)
        return None

    piece = weight(lambda m: any(w in m for w in ("medium", "each", "whole", "berry", "large", "small")))
    cup = weight(lambda m: "cup" in m)
    tbsp = weight(lambda m: "tablespoon" in m or "tbsp" in m)
    return piece, cup, tbsp


def clean_name(raw: str) -> str:
    """Convert USDA all-caps descriptions to readable Title Case names.
    e.g. 'APPLES, RAW, WITH SKIN' → 'Apples, Raw, With Skin'
    Then simplify: strip trailing qualifiers like ', Raw' or ', Cooked' for brevity.
    """
    name = raw.strip().title()
    # Shorten common USDA suffixes that add noise without meaning
    for suffix in (
        ", Raw", ", Cooked", ", Fresh", ", Plain", ", Dry", ", Unenriched",
        ", Enriched", ", Whole", ", Sliced", ", Chopped", ", Frozen", ", Canned",
    ):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
    return name


def usda_to_entry(food: dict) -> dict | None:
    name = clean_name(food.get("description") or "")
    if not name:
        return None

    nutrients = food.get("foodNutrients") or []
    portions = food.get("foodPortions") or []

    # 2048=Atwater Specific, 2047=Atwater General, 1008=Energy — all kcal; skip 1062 (kJ)
    cal = nutrient_value(nutrients, 2048, 2047, NID["calories"])
    protein = nutrient_value(nutrients, NID["protein"])
    carbs = nutrient_value(nutrients, NID["carbs"])
    fat = nutrient_value(nutrients, NID["fat"], 1085)  # 1085 = Total fat (NLEA), used by oils
    fiber = nutrient_value(nutrients, NID["fiber"])
    sodium = nutrient_value(nutrients, NID["sodium"])
    sugar = nutrient_value(nutrients, NID["sugar"])

    if cal <= 0:
        # Fallback: Atwater general formula (works well for oils, butter, dry legumes)
        cal = round(protein * 4 + carbs * 4 + fat * 9, 1)
    if cal <= 0:
        return None

    usda_cat = (food.get("foodCategory") or {}).get("description", "")
    category = CATEGORY_MAP.get(usda_cat, "Grocery")

    piece_g, cup_g, tbsp_g = extract_unit_weights(portions)

    entry: dict = {
        "name": name,
        "category": category,
        "serving_size": 100,
        "serving_unit": "g",
        "calories": round(cal, 1),
        "protein_g": round(protein, 2),
        "carbs_g": round(carbs, 2),
        "fat_g": round(fat, 2),
        "fiber_g": round(fiber, 2),
        "source": "USDA",
    }
    if sodium > 0:
        entry["sodium_mg"] = round(sodium, 1)
    if sugar > 0:
        entry["sugar_g"] = round(sugar, 2)
    if piece_g:
        entry["piece_size_g"] = piece_g
    if cup_g:
        entry["cup_size_g"] = cup_g
    if tbsp_g:
        entry["tbsp_size_g"] = tbsp_g

    return entry


def normalize(name: str) -> str:
    return " ".join(name.lower().split())


def main():
    dump_path = ensure_dump()
    usda_data = json.loads(dump_path.read_text())
    usda_foods = usda_data["FoundationFoods"]
    print(f"USDA Foundation Foods: {len(usda_foods)}")

    existing = json.loads(FOODS_JSON.read_text())
    existing_names = {normalize(f["name"]) for f in existing}
    print(f"Existing Drift foods: {len(existing)}")

    new_entries: list[dict] = []
    seen: set[str] = set(existing_names)
    skipped_no_cal = 0
    skipped_dup = 0

    for food in usda_foods:
        entry = usda_to_entry(food)
        if entry is None:
            skipped_no_cal += 1
            continue
        key = normalize(entry["name"])
        if key in seen:
            skipped_dup += 1
            continue
        seen.add(key)
        new_entries.append(entry)

    print(f"Skipped (no calories): {skipped_no_cal}")
    print(f"Skipped (duplicates):  {skipped_dup}")
    print(f"New USDA foods:        {len(new_entries)}")

    if len(new_entries) < 300:
        print(f"WARNING: Only {len(new_entries)} new foods — below 300 target.")

    if DRY_RUN:
        print("\nDRY RUN — not writing to foods.json")
        print("Sample entries:")
        for e in new_entries[:8]:
            print(f"  [{e['category']}] {e['name']} — {e['calories']} cal/100g  P:{e['protein_g']} C:{e['carbs_g']} F:{e['fat_g']}")
        return

    merged = existing + new_entries
    FOODS_JSON.write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n")
    print(f"\n✓ foods.json updated: {len(existing)} → {len(merged)} (+{len(new_entries)} USDA)")


if __name__ == "__main__":
    main()
