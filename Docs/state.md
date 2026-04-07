# Drift — Current State (April 2026)

## Overview
AI-first local health tracker. AI chat is the primary interface — every data entry doable through conversation. Traditional UI for visual analytics and fallback. No cloud, no accounts. Published on TestFlight as "Drift Fitness" (bundle: com.drift.health).

## Numbers
- **Version:** 0.1.0, Build 87
- **Tests:** 729+ (19 test files, 248 methods)
- **AI Eval:** 212+ methods + 100-query LLM eval
- **Foods:** 1004+ (Indian, Mexican, global)
- **Exercises:** 873 (free-exercise-db)
- **Biomarkers:** 65 across 9 categories
- **AI Chat Features:** 25+ (see `Docs/ai-parity.md`)

## Tech Stack
- SwiftUI + MVVM, iOS 17+, Swift 6
- GRDB.swift for SQLite (only SPM dependency)
- llama.cpp xcframework (rebuilt from source, Metal GPU)
- XcodeGen for project generation

## AI System — Dual-Model
- **SmolLM2-360M Q8** (368MB) — 6GB devices. Reliable harness, hardcoded rules do heavy lifting.
- **Gemma 4 E2B Q4_K_M** (2900MB) — 8GB+ devices. Intelligence layer, all tools, multi-turn capable.
- **Backend:** Raw llama.cpp C API, Metal GPU (36 layers offloaded, ~3GB VRAM)
- **Auto-detect:** RAM >= 6.5GB → Gemma 4, >= 5.0GB → SmolLM
- **Auto-unload:** 60s idle, reload on return ("Preparing AI assistant...")
- **Tools:** 10 JSON tools. Gemma sees all, SmolLM sees 6 screen-filtered.
- **Parity:** See `Docs/ai-parity.md` for what's in chat vs UI-only.

## AI Chat Capabilities
- Food: log single/multi/meal/gram, nutrition lookup, suggestions, summaries
- Weight: log, trend, goal progress
- Exercise: start template, smart workout (coach me), log exercises, suggestion, overload
- Health: sleep/recovery, supplements, glucose, biomarkers, body comp
- Meta: explain TDEE, daily/weekly/yesterday summary, calories left, protein status

## Tab Structure
Dashboard | Weight | Food | Exercise | More

## Apple Developer
- Team ID: ZJ5H5XH82A
- API Key: 623N7AD6BJ, Issuer: ad762446-bede-4bcd-9776-a3613c669447
- TestFlight: https://testflight.apple.com/join/NDxkRwRq
