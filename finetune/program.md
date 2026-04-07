# Drift Fine-Tune Loop

## Steering
- model: qwen2.5-1.5b
- focus: weight, exercise
- data_budget: 200
- override: CONTINUE

## Recovery
If loop crashes, re-read results.tsv for last good checkpoint.
Resume training from the latest checkpoint in output/.

## Process
1. Re-read this file every cycle
2. Find weakest category from last eval
3. Generate targeted examples (data_budget per cycle)
4. Validate + merge into training set
5. Fine-tune with LoRA
6. Eval on held-out set
7. If WTCA improved → keep, else discard
8. Every 5 keeps → deep train
9. Loop forever (or until override: STOP)

## Notes
- Start by generating ALL categories: `python data/generate_data.py --all`
- Then run the loop: `python loop.py --config config/qwen2.5-1.5b.yaml`
- Change focus to target specific weak areas
- Set override to STOP to halt the loop gracefully
