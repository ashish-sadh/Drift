#!/usr/bin/env python3
"""
Local synthetic data generator — no API needed.
Uses extensive hand-crafted query variations + randomized context injection.

Usage:
    python data/generate_local.py
    python data/generate_local.py --output data/all_generated.jsonl
"""

import argparse
import json
import random
from pathlib import Path

from templates import (
    system_prompt,
    random_context,
)

random.seed(42)

# ============================================================
# FOOD LOGGING (300 examples)
# ============================================================
FOOD_LOG_TEMPLATES = [
    # Basic patterns
    "I had {food}", "ate {food}", "log {food}", "add {food}",
    "had {food}", "just had {food}", "I ate {food}", "I just ate {food}",
    "logged {food}", "track {food}", "I made {food}", "made {food}",
    "eating {food}", "I'm eating {food}", "having {food}", "I'm having {food}",
    "drank {food}", "I drank {food}", "drinking {food}",
    # With amounts
    "I had {amount} {food}", "ate {amount} {food}", "log {amount} {food}",
    "had {amount} {food}", "just had {amount} {food}",
    # With meal hints
    "had {food} for breakfast", "ate {food} for lunch", "had {food} for dinner",
    "log {food} for breakfast", "{food} for lunch", "{food} for dinner",
    "had {food} as a snack", "ate {food} for brunch",
    # With amounts and meals
    "had {amount} {food} for breakfast", "ate {amount} {food} for lunch",
    "log {amount} {food} for dinner",
    # Casual/slang
    "just finished {food}", "grabbed {food}", "wolfed down {food}",
    "munched on {food}", "snacked on {food}", "devoured {food}",
    "chowed down on {food}", "polished off {food}",
    # Formal
    "I'd like to log {food}", "please add {food}", "could you log {food}",
    "please track {food}", "add {food} please",
    # Compound
    "had {food} and {food2}", "ate {food} with {food2}",
    "log {food} and {food2}",
]

FOODS = [
    "eggs", "chicken breast", "banana", "rice", "dal", "samosa", "rotis",
    "paneer butter masala", "biryani", "milk", "coffee", "pizza", "pasta",
    "sandwich", "oatmeal", "soup", "protein shake", "toast with butter",
    "avocado", "yogurt", "salad", "steak", "salmon", "tuna", "shrimp",
    "tofu", "lentils", "chickpeas", "hummus", "falafel", "naan",
    "dosa", "idli", "upma", "poha", "paratha", "chole", "rajma",
    "palak paneer", "butter chicken", "tandoori chicken", "fish curry",
    "fried rice", "noodles", "ramen", "sushi", "tacos", "burrito",
    "quesadilla", "nachos", "burger", "fries", "hot dog", "wings",
    "mac and cheese", "grilled cheese", "pb&j", "cereal", "granola",
    "smoothie", "juice", "tea", "chai", "lassi", "coconut water",
    "almonds", "peanuts", "cashews", "trail mix", "dark chocolate",
    "ice cream", "cake", "cookies", "brownie", "muffin", "bagel",
    "croissant", "pancakes", "waffles", "french toast", "bacon",
    "sausage", "ham", "turkey", "cottage cheese", "greek yogurt",
    "protein bar", "apple", "orange", "grapes", "mango", "pineapple",
    "watermelon", "strawberries", "blueberries", "papaya", "guava",
    "pomegranate", "kiwi", "pear", "peach", "plum", "dates",
    "corn", "broccoli", "spinach", "carrots", "sweet potato",
    "potato", "beans", "peas", "mushrooms", "bell pepper", "cucumber",
    "tomato", "onion", "garlic bread", "khichdi", "dal chawal",
    "aloo gobi", "bhindi", "baingan bharta", "malai kofta",
    "pav bhaji", "vada pav", "misal pav", "pani puri",
    "spring rolls", "dim sum", "pad thai", "green curry",
    "bibimbap", "kimchi", "gyoza", "tempura", "poke bowl",
    "acai bowl", "overnight oats", "chia pudding", "energy balls",
]

FOODS_COMPOUND = [
    ("chicken", "rice"), ("dal", "rice"), ("eggs", "toast"),
    ("rice", "beans"), ("pasta", "salad"), ("burger", "fries"),
    ("soup", "bread"), ("steak", "potatoes"), ("fish", "chips"),
    ("naan", "curry"), ("roti", "sabzi"), ("dosa", "chutney"),
    ("idli", "sambar"), ("pancakes", "bacon"), ("cereal", "milk"),
    ("yogurt", "granola"), ("sandwich", "chips"), ("tacos", "guac"),
    ("coffee", "muffin"), ("tea", "biscuits"),
]

AMOUNTS = [
    "2", "3", "1", "4", "5", "half", "a couple of", "some", "a few",
    "a bowl of", "a plate of", "a cup of", "a glass of", "a piece of",
    "a slice of", "two", "three", "a handful of", "1.5", "a serving of",
    "a big bowl of", "a small plate of", "half a", "a large",
    "200g of", "100g of", "a scoop of", "two scoops of",
]


def gen_food_logging(count: int) -> list[dict]:
    examples = []
    used = set()

    while len(examples) < count:
        template = random.choice(FOOD_LOG_TEMPLATES)
        food = random.choice(FOODS)
        amount = random.choice(AMOUNTS) if "{amount}" in template else None

        if "{food2}" in template:
            f1, f2 = random.choice(FOODS_COMPOUND)
            query = template.replace("{food}", f1).replace("{food2}", f2)
            food_name = f"{f1} and {f2}"
        elif amount:
            query = template.replace("{amount}", amount).replace("{food}", food)
            food_name = food
        else:
            query = template.replace("{food}", food)
            food_name = food

        if query.lower() in used:
            continue
        used.add(query.lower())

        # Build tool call
        params = {"name": food_name}
        if amount and amount not in ("some", "a few", "half", "a handful of"):
            # Extract numeric amount
            num_map = {"1": "1", "2": "2", "3": "3", "4": "4", "5": "5",
                       "two": "2", "three": "3", "1.5": "1.5",
                       "a couple of": "2", "half a": "0.5", "a large": "1",
                       "a bowl of": "1", "a plate of": "1", "a cup of": "1",
                       "a glass of": "1", "a piece of": "1", "a slice of": "1",
                       "a serving of": "1", "a big bowl of": "1", "a small plate of": "1",
                       "200g of": "200", "100g of": "100",
                       "a scoop of": "1", "two scoops of": "2"}
            amt = num_map.get(amount, "1")
            params["amount"] = amt
        else:
            params["amount"] = "1"

        tool_call = json.dumps({"tool": "log_food", "params": params}, separators=(",", ":"))
        examples.append(make_example(query, tool_call, "food_logging", "food"))

    return examples


# ============================================================
# FOOD QUESTIONS (350 examples)
# ============================================================
FOOD_QUESTION_TEMPLATES = [
    # Calories/nutrition
    "how many calories in {food}", "calories in {food}", "how much protein in {food}",
    "what's the protein in {food}", "carbs in {food}", "fat in {food}",
    "nutrition info for {food}", "nutritional value of {food}",
    "is {food} healthy", "is {food} good for me", "is {food} high in protein",
    # Remaining/status
    "calories left", "how many calories left", "how many calories remaining",
    "calories left today", "how much can I still eat", "what's my calorie budget",
    "how am I doing on calories", "am I over my calories", "am I under budget",
    "how's my calorie intake", "calorie count today",
    # Macros
    "how's my protein", "how's my protein intake", "am I hitting my macros",
    "how are my macros", "macro breakdown", "macro balance today",
    "am I getting enough protein", "protein status", "how much protein today",
    "need more protein", "protein intake so far",
    # What to eat
    "what should I eat", "what should I eat for dinner", "what should I have for lunch",
    "what can I eat", "suggest something to eat", "meal suggestion",
    "suggest something high protein", "what's a good snack",
    "suggest a healthy meal", "what should I have for breakfast",
    "I'm hungry what should I have", "recommend something to eat",
    "what's a low calorie snack", "high protein meal ideas",
    "I need something light", "what's good for post workout",
    # Diet questions
    "am I eating too much", "am I eating enough", "is my diet balanced",
    "am I on track with food", "how's my diet", "am I eating healthy",
    "I need to eat more fiber", "I need more vegetables",
    # Today's food
    "what did I eat today", "what have I eaten", "show my food log",
    "food today", "today's meals", "what did I have for lunch",
    "my food for today", "meals today", "show me what I ate",
    # Specific food queries
    "how many calories in a samosa", "protein in chicken breast",
    "is rice high in carbs", "how much sugar in a banana",
    "calories in a slice of pizza", "is oatmeal good for weight loss",
    "what has more protein chicken or fish", "is paneer high in protein",
    "calories in biryani", "how heavy is a serving of rice",
    "is dal a good protein source", "compare chicken and tofu",
    # Explain
    "how are my calories calculated", "what's my TDEE",
    "why is my target {target}", "explain my calorie target",
    "how does calorie tracking work",
]

FOOD_Q_PARAMS_TEMPLATES = [
    # These get food_info with a query param
    ("how many calories in {food}", "{food} calories"),
    ("protein in {food}", "protein in {food}"),
    ("is {food} healthy", "{food} healthy"),
    ("nutrition info for {food}", "{food} nutrition"),
    ("is {food} high in protein", "{food} protein"),
]

TARGETS = ["1500", "1800", "2000", "2200", "2500"]


def gen_food_questions(count: int) -> list[dict]:
    examples = []
    used = set()

    while len(examples) < count:
        template = random.choice(FOOD_QUESTION_TEMPLATES)
        food = random.choice(FOODS)
        target = random.choice(TARGETS)
        query = template.replace("{food}", food).replace("{target}", target)

        if query.lower() in used:
            continue
        used.add(query.lower())

        # Determine params
        params = {}
        if any(food in query for food in FOODS):
            # Has a specific food — add query param
            for t, q in FOOD_Q_PARAMS_TEMPLATES:
                if t.replace("{food}", food) == query:
                    params["query"] = q.replace("{food}", food)
                    break

        tool_call = json.dumps({"tool": "food_info", "params": params}, separators=(",", ":"))
        examples.append(make_example(query, tool_call, "food_questions", "food"))

    return examples


# ============================================================
# WEIGHT LOGGING (250 examples)
# ============================================================
WEIGHT_LOG_TEMPLATES = [
    "I weigh {value} {unit}", "my weight is {value} {unit}",
    "scale says {value} {unit}", "weighed in at {value} {unit}",
    "I'm {value} {unit}", "weight today is {value} {unit}",
    "{value} {unit} today", "{value} {unit} this morning",
    "I'm at {value} {unit}", "weighed {value} {unit} today",
    "log {value} {unit}", "weight: {value} {unit}",
    "just weighed myself {value} {unit}", "stepped on the scale {value} {unit}",
    "morning weight {value} {unit}", "weight this morning {value} {unit}",
    "I weighed in {value} {unit}", "logged {value} {unit}",
    "weigh {value} {unit}", "current weight {value} {unit}",
    "body weight {value} {unit}", "today's weight {value} {unit}",
    "I'm currently {value} {unit}", "came in at {value} {unit}",
    "the scale read {value} {unit}", "scale showed {value} {unit}",
    # Without explicit unit (defaults to lbs)
    "I weigh {value}", "scale says {value}", "weighed in at {value}",
    "{value} on the scale", "weight is {value}", "I'm {value} today",
]

WEIGHT_LBS = [str(w) for w in range(110, 260, 1)]
WEIGHT_KG = [str(w) for w in range(50, 120, 1)]


def gen_weight_logging(count: int) -> list[dict]:
    examples = []
    used = set()

    while len(examples) < count:
        template = random.choice(WEIGHT_LOG_TEMPLATES)

        if "{unit}" in template:
            if random.random() < 0.6:
                value = random.choice(WEIGHT_LBS)
                unit = random.choice(["lbs", "pounds", "lb"])
            else:
                value = random.choice(WEIGHT_KG)
                unit = random.choice(["kg", "kilos", "kgs"])
            query = template.replace("{value}", value).replace("{unit}", unit)
            unit_norm = "lbs" if unit in ("lbs", "pounds", "lb") else "kg"
        else:
            value = random.choice(WEIGHT_LBS)
            query = template.replace("{value}", value)
            unit_norm = "lbs"

        if query.lower() in used:
            continue
        used.add(query.lower())

        # Add decimal weight variants
        if random.random() < 0.3:
            decimal = random.choice([".2", ".4", ".5", ".6", ".8"])
            value = value + decimal

        params = {"value": value, "unit": unit_norm}
        tool_call = json.dumps({"tool": "log_weight", "params": params}, separators=(",", ":"))
        examples.append(make_example(query, tool_call, "weight_logging", "weight"))

    return examples


# ============================================================
# WEIGHT QUESTIONS (150 examples)
# ============================================================
WEIGHT_QUESTION_QUERIES = [
    "how's my weight trend", "am I on track to reach my goal",
    "how much have I lost this month", "show my weight history",
    "what's my body fat", "what's my BMI", "am I losing weight",
    "how fast am I losing", "what's my goal progress",
    "when will I reach my target", "my weight is going up why",
    "weight trend", "show weight graph", "weight progress",
    "am I gaining or losing", "how much do I need to lose",
    "how's my weight loss going", "weight loss progress",
    "how many pounds left to goal", "how many kg to go",
    "am I making progress on weight", "weight check",
    "how close am I to my goal weight", "how far from target",
    "what's my ideal weight", "is my weight healthy",
    "am I at a healthy weight", "weight loss rate",
    "how long till I reach goal", "estimated time to goal",
    "how much weight did I lose this week", "weekly weight change",
    "am I on track", "is my weight trending down",
    "show me my weight over the last month", "monthly weight change",
    "how consistent has my weight been", "weight fluctuation",
    "what's my lowest weight recently", "what's my highest weight recently",
    "average weight this week", "weight comparison month over month",
    "am I losing too fast", "am I losing too slow",
    "is my weight loss sustainable", "should I eat more or less",
    "what's happening with my weight", "why am I plateauing",
    "weight plateau", "am I in a plateau", "why is my weight stuck",
    "body composition", "lean mass vs fat", "body fat percentage",
    "how much muscle am I carrying", "what's my muscle mass",
    "how's my body recomp going", "am I gaining muscle",
    "how does my weight compare to last month",
    "weight trend for the past 3 months", "show my weight data",
    "am I where I should be", "should I adjust my goal",
    "how realistic is my weight goal", "is my goal achievable",
    "how's my cut going", "how's my bulk going", "am I in a deficit",
    "is my deficit working", "calorie deficit and weight loss",
    "what rate should I lose weight", "healthy weight loss rate",
]


def gen_weight_questions(count: int) -> list[dict]:
    examples = []
    queries = WEIGHT_QUESTION_QUERIES.copy()
    random.shuffle(queries)

    for q in queries[:count]:
        tool_call = json.dumps({"tool": "weight_info", "params": {}}, separators=(",", ":"))
        examples.append(make_example(q, tool_call, "weight_questions", "weight"))

    # Pad with variations if needed
    prefixes = ["hey ", "so ", "quick question - ", "yo ", "umm ", ""]
    while len(examples) < count:
        base = random.choice(WEIGHT_QUESTION_QUERIES)
        prefix = random.choice(prefixes)
        q = prefix + base
        tool_call = json.dumps({"tool": "weight_info", "params": {}}, separators=(",", ":"))
        examples.append(make_example(q, tool_call, "weight_questions", "weight"))

    return examples[:count]


# ============================================================
# EXERCISE START (200 examples)
# ============================================================
EXERCISE_START_TEMPLATES = [
    "start {workout}", "start {workout} workout", "begin {workout}",
    "let's do {workout}", "I want to do {workout}", "let's hit {workout}",
    "begin {workout} workout", "start a {workout} workout",
    "build me a {workout} workout", "create a {workout} session",
    "start my {workout} session", "kick off {workout}",
    "time for {workout}", "ready for {workout}", "let's go {workout}",
    "I wanna train {workout}", "wanna hit {workout}",
    "give me a {workout} routine", "plan a {workout} workout",
    "set up {workout} workout", "coach me through {workout}",
    "start {workout} day", "today is {workout} day",
    "it's {workout} day", "{workout} time", "let's get {workout} done",
    "I need a {workout} workout", "design a {workout} session",
    "suggest exercises for {workout}", "give me a quick {workout} workout",
]

WORKOUTS = [
    "chest", "back", "legs", "arms", "shoulders", "core", "abs",
    "push", "pull", "push day", "pull day", "leg day",
    "upper body", "lower body", "full body", "cardio",
    "chest and triceps", "back and biceps", "shoulders and arms",
    "glutes", "hamstrings", "quads", "calves",
    "PPL", "upper lower", "bro split",
    "hypertrophy", "strength", "HIIT",
    "bench press", "squat", "deadlift",
]


def gen_exercise_start(count: int) -> list[dict]:
    examples = []
    used = set()

    while len(examples) < count:
        template = random.choice(EXERCISE_START_TEMPLATES)
        workout = random.choice(WORKOUTS)
        query = template.replace("{workout}", workout)

        if query.lower() in used:
            continue
        used.add(query.lower())

        params = {"name": workout}
        tool_call = json.dumps({"tool": "start_workout", "params": params}, separators=(",", ":"))
        examples.append(make_example(query, tool_call, "exercise_start", "exercise"))

    return examples


# ============================================================
# EXERCISE QUESTIONS (200 examples)
# ============================================================
EXERCISE_QUESTION_QUERIES = [
    "what should I train today", "what muscle haven't I trained",
    "how many workouts this week", "am I making progress on bench",
    "am I getting stronger on squats", "I want to work out",
    "what did I train last", "how's my training volume",
    "is my bench press improving", "what should I train next",
    "what's my workout streak", "how many days since last workout",
    "when did I last train legs", "when did I last train chest",
    "am I overtraining", "should I take a rest day",
    "how's my squat progress", "how's my deadlift progress",
    "what's my bench press max", "what's my squat max",
    "am I lifting more than last month", "strength progress",
    "workout frequency", "how often am I training",
    "training split", "what's my current split",
    "how balanced is my training", "am I neglecting any muscles",
    "which body part needs work", "weakest muscle group",
    "how's my consistency", "workout consistency this month",
    "total volume this week", "sets per muscle group",
    "am I doing enough for chest", "am I doing enough for back",
    "progressive overload", "am I progressing",
    "workout history", "show my workout log",
    "how many sets today", "total reps this week",
    "compare this week to last week", "training load",
    "recovery between workouts", "am I recovered enough to train",
    "exercise recommendations", "what exercises for back",
    "best exercise for chest", "how to improve squat",
    "good exercises for shoulders", "what's a good arm workout",
    "how to get stronger", "training tips",
    "form check for deadlift", "proper bench press form",
]

EXERCISE_SPECIFIC = [
    ("am I making progress on {ex}", {"exercise": "{ex}"}),
    ("how's my {ex} progress", {"exercise": "{ex}"}),
    ("what's my {ex} max", {"exercise": "{ex}"}),
    ("am I getting stronger on {ex}", {"exercise": "{ex}"}),
    ("show {ex} history", {"exercise": "{ex}"}),
    ("last time I did {ex}", {"exercise": "{ex}"}),
]

EXERCISES = [
    "bench press", "squat", "deadlift", "overhead press", "barbell row",
    "pull ups", "push ups", "dips", "lunges", "leg press",
    "lat pulldown", "cable rows", "bicep curls", "tricep extensions",
    "shoulder press", "lateral raises", "face pulls", "hip thrusts",
]


def gen_exercise_questions(count: int) -> list[dict]:
    examples = []

    # General queries
    for q in EXERCISE_QUESTION_QUERIES:
        tool_call = json.dumps({"tool": "exercise_info", "params": {}}, separators=(",", ":"))
        examples.append(make_example(q, tool_call, "exercise_questions", "exercise"))

    # Specific exercise queries
    for template, params_template in EXERCISE_SPECIFIC:
        for ex in EXERCISES:
            q = template.replace("{ex}", ex)
            params = {k: v.replace("{ex}", ex) for k, v in params_template.items()}
            tool_call = json.dumps({"tool": "exercise_info", "params": params}, separators=(",", ":"))
            examples.append(make_example(q, tool_call, "exercise_questions", "exercise"))

    random.shuffle(examples)
    return examples[:count]


# ============================================================
# SLEEP/RECOVERY (100 examples)
# ============================================================
SLEEP_QUERIES = [
    "how'd I sleep last night", "what's my recovery score",
    "should I train today or rest", "I'm feeling tired",
    "what's my HRV", "am I recovered enough", "how's my resting heart rate",
    "I feel exhausted", "did I sleep well", "is my recovery good enough to lift",
    "how many hours did I sleep", "sleep quality last night",
    "am I well rested", "sleep score", "sleep data",
    "how's my sleep been lately", "sleep trend this week",
    "am I sleeping enough", "I didn't sleep well",
    "I slept great last night", "my sleep was terrible",
    "recovery status", "am I ready to train",
    "should I rest today", "do I need more rest",
    "how's my energy level", "I feel drained",
    "fatigue level", "am I overtrained",
    "heart rate variability", "HRV trend",
    "resting heart rate trend", "morning heart rate",
    "is my body recovered", "readiness score",
    "readiness to train", "should I go hard or easy today",
    "can I do a heavy session", "am I fresh enough for legs",
    "sleep hours this week", "average sleep",
    "deep sleep last night", "REM sleep",
    "time in bed vs asleep", "sleep efficiency",
    "what time did I fall asleep", "what time did I wake up",
    "sleep consistency", "am I going to bed too late",
    "how does my sleep compare to last week",
    "I keep waking up at night", "sleep interruptions",
    "I'm not sleeping well", "tips for better sleep",
    "how much sleep do I need", "optimal sleep duration",
    "is 6 hours enough sleep", "I only got 5 hours",
    "recovery recommendations", "what helps recovery",
    "stress and recovery", "how stressed am I",
    "nervous system recovery", "parasympathetic score",
]


def gen_sleep_recovery(count: int) -> list[dict]:
    examples = []
    for q in SLEEP_QUERIES[:count]:
        tool_call = json.dumps({"tool": "sleep_recovery", "params": {}}, separators=(",", ":"))
        examples.append(make_example(q, tool_call, "sleep_recovery", "dashboard"))

    prefixes = ["hey ", "quick - ", "btw ", ""]
    while len(examples) < count:
        q = random.choice(prefixes) + random.choice(SLEEP_QUERIES)
        tool_call = json.dumps({"tool": "sleep_recovery", "params": {}}, separators=(",", ":"))
        examples.append(make_example(q, tool_call, "sleep_recovery", "dashboard"))

    return examples[:count]


# ============================================================
# SUPPLEMENTS (100 examples)
# ============================================================
SUPPLEMENT_QUERIES = [
    "did I take my vitamins", "what supplements should I take",
    "have I had my creatine today", "supplement status",
    "which vitamins did I take", "vitamin check",
    "did I take my fish oil", "omega 3 status",
    "have I taken my protein today", "creatine status",
    "what supplements am I missing", "remaining supplements",
    "supplement log", "show my supplements",
    "did I take vitamin D", "vitamin D status",
    "have I had my magnesium", "zinc status",
    "iron supplement", "B12 today", "multivitamin check",
    "did I take my meds", "medication check",
    "supplements today", "what's left to take",
    "am I up to date on supplements", "supplement reminder",
    "what should I supplement", "do I need any supplements",
    "supplement recommendations", "what vitamins do I need",
    "pre workout today", "post workout supplement",
    "protein powder", "collagen supplement",
    "ashwagandha today", "melatonin", "probiotics",
    "electrolytes", "BCAA", "glutamine",
    "have I taken everything", "all supplements done",
    "what's pending", "supplement checklist",
    "how many supplements left", "daily supplement count",
    "morning supplements done", "evening supplements",
    "did I forget any supplements", "missed supplements",
]


def gen_supplements(count: int) -> list[dict]:
    examples = []
    for q in SUPPLEMENT_QUERIES[:count]:
        tool_call = json.dumps({"tool": "supplements", "params": {}}, separators=(",", ":"))
        examples.append(make_example(q, tool_call, "supplements", "dashboard"))

    while len(examples) < count:
        q = random.choice(SUPPLEMENT_QUERIES)
        tool_call = json.dumps({"tool": "supplements", "params": {}}, separators=(",", ":"))
        examples.append(make_example(q, tool_call, "supplements", "dashboard"))

    return examples[:count]


# ============================================================
# NO TOOL - CHAT (200 examples)
# ============================================================
NO_TOOL_QUERIES_AND_RESPONSES = [
    ("thanks", "You're welcome!"),
    ("thanks!", "Happy to help!"),
    ("thank you", "Anytime!"),
    ("thank you so much", "Glad I could help!"),
    ("ty", "You're welcome!"),
    ("thx", "No problem!"),
    ("hello", "Hey! How can I help you today?"),
    ("hi", "Hi! What can I help you track?"),
    ("hey", "Hey! What's up?"),
    ("hey there", "Hi! Need help tracking something?"),
    ("good morning", "Good morning! Ready to track your day?"),
    ("good evening", "Good evening! How can I help?"),
    ("good night", "Good night! Get some rest."),
    ("what's up", "Not much! Need help logging food or checking your stats?"),
    ("howdy", "Hey! What can I do for you?"),
    ("ok", "Got it!"),
    ("ok got it", "Great, let me know if you need anything else!"),
    ("cool", "Awesome!"),
    ("nice", "Glad to hear it!"),
    ("great", "Let me know if you need anything else!"),
    ("perfect", "Glad that helped!"),
    ("awesome", "Let me know if you need anything!"),
    ("sounds good", "Great!"),
    ("sure", "What would you like to do?"),
    ("got it", "Let me know if you need anything else!"),
    ("what can you do", "I can help you track food, log weight, start workouts, check sleep, and more! Just tell me what you need."),
    ("help", "I can log food, track weight, start workouts, and show your health data. What would you like to do?"),
    ("what are you", "I'm your health tracking assistant! I help with food logging, weight tracking, workouts, and more."),
    ("how do you work", "Just tell me what you ate, your weight, or ask about your health data and I'll take care of it!"),
    ("you're helpful", "Thanks! Happy to help anytime."),
    ("you're great", "Thank you! Let me know if you need anything."),
    ("good job", "Thanks! Glad I could help."),
    ("well done", "Thank you!"),
    ("nice work", "Appreciate it!"),
    ("lol", "Haha! Anything else I can help with?"),
    ("haha", "What else can I do for you?"),
    ("😂", "Haha! Need anything else?"),
    ("🙏", "You're welcome!"),
    ("👍", "Let me know if you need anything!"),
    ("nevermind", "No worries! I'm here when you need me."),
    ("nah", "No problem!"),
    ("nothing", "Ok! Let me know when you need something."),
    ("forget it", "No worries!"),
    ("that's all", "Great, have a good one!"),
    ("I'm done", "Cool! I'll be here when you need me."),
    ("bye", "See you later! Keep up the good work."),
    ("see ya", "Later! Stay on track!"),
    ("later", "See you! Keep crushing it."),
    ("goodnight", "Night! Get some good rest."),
    # General health questions (educational, not tracking)
    ("what is TDEE", "TDEE is Total Daily Energy Expenditure — the total calories your body burns each day including exercise. It's used to set your calorie target."),
    ("what is a macro", "Macros are macronutrients: protein, carbs, and fat. They make up the calories in your food. Tracking them helps optimize your diet."),
    ("what is BMI", "BMI is Body Mass Index — weight divided by height squared. It's a rough indicator of body composition but doesn't account for muscle mass."),
    ("is keto good", "Keto can work for some people, but it's very restrictive. The best diet is one you can sustain long-term. Focus on hitting your calorie and protein targets."),
    ("is creatine safe", "Yes, creatine is one of the most researched supplements. 3-5g daily is safe and effective for most people. Stay hydrated."),
    ("what is progressive overload", "Progressive overload means gradually increasing the demands on your muscles over time — more weight, more reps, or more sets. It's key for strength gains."),
    ("how do I lose belly fat", "You can't spot-reduce fat. A calorie deficit, adequate protein, and resistance training will reduce overall body fat including your midsection."),
    ("is intermittent fasting good", "IF can help some people manage calories, but it's not magic. What matters most is total calories and protein intake throughout the day."),
    ("how much water should I drink", "A good starting point is half your body weight in ounces. More if you're active or in a hot climate. Hydration affects performance and recovery."),
    ("what's a good heart rate", "Resting heart rate of 60-80 bpm is normal. Athletes often have lower. Check trends over time rather than single readings."),
    ("should I do cardio", "Some cardio is great for heart health and recovery. 2-3 sessions per week of 20-30 minutes is a good baseline alongside resistance training."),
    ("how much protein do I need", "A good target is 0.7-1g per pound of body weight, especially if you're training and in a deficit. Protein preserves muscle during fat loss."),
    ("what's a calorie deficit", "A calorie deficit means eating fewer calories than your body burns. This is what drives weight loss. A 500 cal/day deficit = roughly 1 lb/week."),
    ("tell me about creatine", "Creatine monohydrate is safe, well-researched, and helps with strength and recovery. 3-5g daily. No need to load or cycle."),
    ("what are good sources of fiber", "Oats, lentils, beans, berries, broccoli, and chia seeds are all great fiber sources. Aim for 25-30g per day."),
    ("how do I build muscle", "Lift progressively heavier, eat enough protein (0.8-1g/lb), sleep well, and be in a slight surplus or at maintenance calories."),
    ("what's a good warmup", "5-10 minutes of light cardio, dynamic stretches, and lighter warm-up sets before your main lifts. Don't skip it."),
    ("how long should I rest between sets", "For strength: 2-5 minutes. For hypertrophy: 1-2 minutes. For endurance: 30-60 seconds. Listen to your body."),
    # Random chat
    ("I feel great today", "That's awesome! Great energy leads to great workouts and good food choices."),
    ("I'm motivated", "Love to hear it! Let's make the most of today."),
    ("I'm not feeling it today", "That's okay — even a light session counts. Consistency over perfection."),
    ("bad day", "Sorry to hear that. Tomorrow's a fresh start. Take care of yourself today."),
    ("I'm stressed", "Sorry to hear that. Exercise and good sleep can help with stress. Take it easy today if you need to."),
    ("I feel sick", "Rest up and stay hydrated. Don't push training when you're sick — recovery first."),
]


def gen_no_tool(count: int) -> list[dict]:
    examples = []
    for q, r in NO_TOOL_QUERIES_AND_RESPONSES[:count]:
        examples.append(make_example(q, r, "no_tool", "dashboard"))

    while len(examples) < count:
        q, r = random.choice(NO_TOOL_QUERIES_AND_RESPONSES)
        examples.append(make_example(q, r, "no_tool", "dashboard"))

    return examples[:count]


# ============================================================
# HARD NEGATIVES (150 examples)
# ============================================================
HARD_NEGATIVES_AND_RESPONSES = [
    # Weight words, NOT log_weight
    ("how much does chicken weigh", "Check the food info for chicken — usually about 4-6 oz per breast."),
    ("I'm weighing my options", "Take your time! Let me know when you've decided."),
    ("the food was heavy", "Rich foods can feel heavy! Need help checking the calories?"),
    ("that meal weighed on me", "Heavy meals happen! Make sure to balance it out later."),
    ("how much does a banana weigh", "A medium banana is about 120g or 4 oz."),
    ("I'm carrying a lot of weight on this project", "Sounds stressful! Let me know if you need help with tracking."),
    ("heavyweight fight tonight", "Enjoy the fight! Let me know if you need anything tracked."),
    ("the weight of evidence", "Not sure I can help with that! I'm better at tracking food and workouts."),
    ("pulling my weight at work", "Sounds like a busy day! Need help logging anything?"),
    ("dead weight", "Need help with something specific?"),
    ("weigh the pros and cons", "Sure, what are you deciding between?"),
    ("light weight baby", "Haha! Ready to start a workout?"),
    # Food words, NOT log_food
    ("food for thought", "What are you thinking about?"),
    ("that's a recipe for disaster", "Haha! What can I help you with?"),
    ("what's cooking", "Not much! What can I help you track?"),
    ("spill the beans", "What's on your mind?"),
    ("that's the icing on the cake", "Sounds like things are going well!"),
    ("bitter pill to swallow", "That's tough. Anything I can help with?"),
    ("full plate today", "Sounds busy! Let me know when you need to log something."),
    ("piece of cake", "Nice! What else can I help with?"),
    ("bring home the bacon", "Haha! Let me know when you actually eat some bacon and I'll log it."),
    ("egg on my face", "Ha! Need anything tracked?"),
    ("I'm toast", "Get some rest! I'll be here when you need me."),
    ("that's bananas", "Haha! Anything I can help with?"),
    ("in a pickle", "What's going on?"),
    ("the apple doesn't fall far from the tree", "Haha! Need anything?"),
    # Exercise words, NOT start_workout
    ("I need to exercise more discipline", "Self-discipline is key! What can I help you with?"),
    ("that was a good exercise in patience", "Ha! Need help with actual exercise tracking?"),
    ("exercise caution", "Will do! Anything else?"),
    ("exercise your rights", "Not my area of expertise! Need help tracking something?"),
    ("mental exercise", "Keeping the brain sharp! Need help with workouts?"),
    ("that workout was killer", "Great job! Recovery is important too."),
    ("yesterday's workout was tough", "Nice work pushing through! How's recovery?"),
    ("I used to work out a lot", "Want to get back into it? I can help set up a routine."),
    ("my friend started working out", "That's great! Want to start a workout yourself?"),
    ("working out the details", "Let me know once you've figured things out!"),
    ("running late", "No worries! I'm here when you're ready."),
    ("running out of time", "What do you need help with quickly?"),
    ("I'm pumped", "Great energy! Ready to start a workout?"),
    # Sleep words, NOT sleep_recovery
    ("let me sleep on it", "Take your time! I'll be here."),
    ("sleeping on the job", "Ha! Need help with anything?"),
    ("that puts me to sleep", "Haha! What can I help with?"),
    ("I could do that in my sleep", "You make it look easy!"),
    ("sleeping beauty", "Ha! Need to check your actual sleep data?"),
    # Supplement words, NOT supplements
    ("supplementary material", "What can I help you with?"),
    ("supplement my income", "Can't help with that! But I can track your health."),
    ("supplemental information", "What do you need to know?"),
    # Questions that sound like tracking but aren't
    ("how many eggs does a chicken lay", "About 250-300 per year! Need to log some eggs?"),
    ("what's the world record bench press", "Over 700 lbs! How's your own bench coming along?"),
    ("how tall is a basketball player", "Average NBA height is about 6'6\". Need help with your own measurements?"),
    ("when was the treadmill invented", "1818! But treadmills as we know them came in the 1950s. Want to log a workout?"),
    ("who invented protein powder", "Eugene Schiff in the 1950s. Want to log a protein shake?"),
    # Ambiguous but should be chat
    ("interesting", "What caught your attention?"),
    ("I see", "Let me know if you have questions!"),
    ("hmm", "What are you thinking about?"),
    ("that makes sense", "Great! Anything else?"),
    ("why", "Can you tell me more about what you're asking?"),
    ("how", "What specifically would you like to know?"),
    ("what", "What would you like to know?"),
    ("really", "Yep! What else can I help with?"),
    ("are you sure", "Yes! Let me know if you want me to double-check something."),
    ("no way", "Ha! What's surprising?"),
    ("seriously", "For real! What can I help with?"),
    ("that's crazy", "What's on your mind?"),
    ("whatever", "Let me know when you need something!"),
    ("idk", "No worries — just let me know what you need help with."),
    ("I'm bored", "Why not check your stats or start a workout?"),
    ("tell me a joke", "Why do we never tell secrets on a farm? Because the potatoes have eyes and the corn has ears! 🌽"),
    ("who are you", "I'm your health tracking assistant! I help with food, weight, workouts, and more."),
    ("are you AI", "Yes! I'm an AI assistant focused on helping you track your health and fitness."),
    ("can you do math", "I focus on health tracking, but your calorie math is built into the app!"),
]


def gen_hard_negatives(count: int) -> list[dict]:
    examples = []
    for q, r in HARD_NEGATIVES_AND_RESPONSES[:count]:
        examples.append(make_example(q, r, "hard_negatives", "dashboard"))

    while len(examples) < count:
        q, r = random.choice(HARD_NEGATIVES_AND_RESPONSES)
        examples.append(make_example(q, r, "hard_negatives", "dashboard"))

    return examples[:count]


# ============================================================
# HELPER
# ============================================================
def make_example(query: str, assistant_response: str, category: str, screen: str) -> dict:
    sys = system_prompt(screen)
    context = random_context()
    user = f"Context about the user:\n{context}\n\nUser: {query}"
    return {
        "system": sys,
        "user": user,
        "assistant": assistant_response,
        "category": category,
        "query": query,
    }


# ============================================================
# MAIN
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Generate synthetic training data locally")
    parser.add_argument("--output", type=str, default="data/all_generated.jsonl")
    args = parser.parse_args()

    generators = [
        ("food_logging", gen_food_logging, 300),
        ("food_questions", gen_food_questions, 350),
        ("weight_logging", gen_weight_logging, 250),
        ("weight_questions", gen_weight_questions, 150),
        ("exercise_start", gen_exercise_start, 200),
        ("exercise_questions", gen_exercise_questions, 200),
        ("sleep_recovery", gen_sleep_recovery, 100),
        ("supplements", gen_supplements, 100),
        ("no_tool", gen_no_tool, 200),
        ("hard_negatives", gen_hard_negatives, 150),
    ]

    all_data = []
    for name, gen_fn, count in generators:
        examples = gen_fn(count)
        all_data.extend(examples)
        print(f"  {name:25s}: {len(examples)} examples")

    # Shuffle
    random.shuffle(all_data)

    # Write
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        for item in all_data:
            f.write(json.dumps(item) + "\n")

    print(f"\nTotal: {len(all_data)} examples → {output_path}")


if __name__ == "__main__":
    main()
