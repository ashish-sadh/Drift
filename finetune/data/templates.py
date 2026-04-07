"""
Production prompt templates — single source of truth.
Mirrors LocalAIService.swift:25-42 and ToolRegistration.swift exactly.
"""

# All 8 tools with their schemas (from ToolRegistration.swift)
TOOLS = [
    {
        "name": "log_food",
        "params": "name:string, amount:number",
        "description": "User wants to LOG/ADD food they ate. Use this when they say 'I had', 'ate', 'log', 'add'.",
    },
    {
        "name": "food_info",
        "params": "query:string",
        "description": "User asks ABOUT food: calories, protein, nutrition, 'what should I eat', diet questions. NOT for logging.",
    },
    {
        "name": "log_weight",
        "params": "value:number, unit:string",
        "description": "User wants to LOG their body weight. Use when they say 'I weigh', 'my weight is', 'scale says'.",
    },
    {
        "name": "weight_info",
        "params": "",
        "description": "User asks ABOUT their weight: trend, progress, goal, body fat, BMI. NOT for logging.",
    },
    {
        "name": "start_workout",
        "params": "name:string",
        "description": "User wants to START or BEGIN a workout. Use when they say 'start', 'begin', 'let's do', or name a body part.",
    },
    {
        "name": "exercise_info",
        "params": "exercise:string",
        "description": "User asks ABOUT workouts: what to train, progress, history, recovery. NOT for starting a workout.",
    },
    {
        "name": "sleep_recovery",
        "params": "",
        "description": "User asks about SLEEP, RECOVERY, HRV, heart rate, tiredness, or whether to rest vs train.",
    },
    {
        "name": "supplements",
        "params": "",
        "description": "User asks about SUPPLEMENTS or VITAMINS: what they took, what's remaining.",
    },
]

# Screen → tool priority mapping (from LLMToolCallingEval.swift:40-53)
SCREEN_TOOL_PRIORITY = {
    "food": ["log_food", "food_info"],
    "weight": ["log_weight", "weight_info"],
    "exercise": ["start_workout", "exercise_info"],
    "dashboard": [],  # no priority, show default order
    "sleep": ["sleep_recovery"],
    "supplements": ["supplements"],
}

# Max tools shown to model at once
MAX_TOOLS_PER_PROMPT = 6


def get_tools_for_screen(screen: str = "dashboard") -> list[dict]:
    """Return up to MAX_TOOLS_PER_PROMPT tools, prioritized by screen."""
    priority_names = SCREEN_TOOL_PRIORITY.get(screen, [])
    priority = [t for t in TOOLS if t["name"] in priority_names]
    rest = [t for t in TOOLS if t["name"] not in priority_names]
    return (priority + rest)[:MAX_TOOLS_PER_PROMPT]


def format_tool_lines(tools: list[dict]) -> str:
    """Format tools as schema lines matching production prompt."""
    lines = []
    for t in tools:
        params = f"({t['params']})" if t["params"] else "()"
        lines.append(f"- {t['name']}{params} — {t['description']}")
    return "\n".join(lines)


def system_prompt(screen: str = "dashboard") -> str:
    """Build the exact system prompt from LocalAIService.swift:25-42."""
    tools = get_tools_for_screen(screen)
    tool_text = format_tool_lines(tools)
    return (
        'You help track food, weight, and workouts. '
        'LOGGING (user ate/did something) → call log tool. '
        'QUESTION (user asks about data) → call info tool. '
        'CHAT (greeting, thanks) → respond naturally, no tool. '
        'Never give health advice. Never invent numbers. '
        'Examples: '
        '"I had 2 eggs" → {"tool":"log_food","params":{"name":"eggs","amount":"2"}} '
        '"calories left" → {"tool":"food_info","params":{}} '
        '"how\'s my weight" → {"tool":"weight_info","params":{}} '
        '"start chest workout" → {"tool":"start_workout","params":{"name":"chest"}} '
        '"what should I train" → {"tool":"exercise_info","params":{}} '
        '"how\'d I sleep" → {"tool":"sleep_recovery","params":{}} '
        '"thanks" → You\'re welcome! (no tool) '
        f'Tools:\n{tool_text}'
    )


# Context injection templates (from AIContextBuilder.swift)
CONTEXT_TEMPLATES = [
    "Calories: {eaten} eaten, {target} target, {remaining} remaining\nMacros: {protein}P {carbs}C {fat}F\nWeight: {weight} lbs, {rate}/wk",
    "Calories: {eaten}/{target} ({remaining} left)\nProtein: {protein}g/{protein_target}g\nWeight trend: {rate}/wk",
    "Today: {eaten} cal eaten, {remaining} remaining\nMacros: {protein}P/{carbs}C/{fat}F\nGoal: {goal_weight} lbs",
    "Food log: {eaten} cal ({meals} meals)\nRemaining: {remaining} cal\nWeight: {weight} lbs, trend {rate}/wk",
]

import random

def random_context() -> str:
    """Generate a random but realistic context string."""
    eaten = random.randint(200, 2200)
    target = random.choice([1500, 1600, 1800, 2000, 2200, 2500])
    remaining = max(0, target - eaten)
    protein = random.randint(20, 180)
    protein_target = random.choice([100, 120, 140, 150, 160, 180])
    carbs = random.randint(30, 300)
    fat = random.randint(10, 100)
    weight = random.randint(110, 240)
    rate = random.choice(["-0.5", "-0.8", "-1.0", "-1.2", "+0.3", "-0.3", "-1.5"])
    goal_weight = weight - random.randint(5, 40)
    meals = random.randint(0, 5)

    template = random.choice(CONTEXT_TEMPLATES)
    return template.format(
        eaten=eaten, target=target, remaining=remaining,
        protein=protein, protein_target=protein_target,
        carbs=carbs, fat=fat, weight=weight, rate=rate,
        goal_weight=goal_weight, meals=meals,
    )


def build_user_prompt(query: str, context: str | None = None) -> str:
    """Build the user turn matching LlamaCppBackend prompt construction."""
    ctx = context or random_context()
    return f"Context about the user:\n{ctx}\n\nUser: {query}"


# ChatML formatting (from LlamaCppBackend.swift:129)
def to_chatml(system: str, user: str, assistant: str) -> str:
    """Format as ChatML matching LlamaCppBackend.swift:129."""
    return (
        f"<|im_start|>system\n{system}<|im_end|>\n"
        f"<|im_start|>user\n{user}<|im_end|>\n"
        f"<|im_start|>assistant\n{assistant}<|im_end|>"
    )


def to_gemma(system: str, user: str, assistant: str) -> str:
    """Format for Gemma models."""
    return (
        f"<start_of_turn>user\n{system}\n\n{user}<end_of_turn>\n"
        f"<start_of_turn>model\n{assistant}<end_of_turn>"
    )


def format_conversation(system: str, user: str, assistant: str, chat_template: str = "chatml") -> str:
    """Format a conversation for the given chat template."""
    if chat_template == "gemma":
        return to_gemma(system, user, assistant)
    return to_chatml(system, user, assistant)


# Categories for data generation
CATEGORIES = {
    "food_logging": {
        "tool": "log_food",
        "count": 300,
        "screen": "food",
        "description": "User wants to LOG food they ate",
    },
    "food_questions": {
        "tool": "food_info",
        "count": 350,
        "screen": "food",
        "description": "User asks ABOUT food, calories, nutrition, diet",
    },
    "weight_logging": {
        "tool": "log_weight",
        "count": 250,
        "screen": "weight",
        "description": "User wants to LOG their body weight",
    },
    "weight_questions": {
        "tool": "weight_info",
        "count": 150,
        "screen": "weight",
        "description": "User asks ABOUT their weight trend, progress, goal",
    },
    "exercise_start": {
        "tool": "start_workout",
        "count": 200,
        "screen": "exercise",
        "description": "User wants to START a workout",
    },
    "exercise_questions": {
        "tool": "exercise_info",
        "count": 200,
        "screen": "exercise",
        "description": "User asks ABOUT workouts, training progress",
    },
    "sleep_recovery": {
        "tool": "sleep_recovery",
        "count": 100,
        "screen": "dashboard",
        "description": "User asks about sleep, recovery, HRV",
    },
    "supplements": {
        "tool": "supplements",
        "count": 100,
        "screen": "dashboard",
        "description": "User asks about supplements or vitamins",
    },
    "no_tool": {
        "tool": None,
        "count": 200,
        "screen": "dashboard",
        "description": "Chat, greetings, general questions — NO tool call",
    },
    "hard_negatives": {
        "tool": None,  # varies — these test NOT triggering the wrong tool
        "count": 150,
        "screen": "dashboard",
        "description": "Tricky queries that should NOT trigger a specific tool",
    },
}
