# LinkedIn version (~240 words)

I built an iOS app called **Drift** — an all-in-one health app with analytics on top of Apple Health, behavior logging for food and exercise, a small on-device LLM for conversational logging (private data never touches the network), and bring-your-own-key support for heavier remote work: plug in your existing Anthropic / OpenAI / Gemini key, it lives in iOS Keychain, you pay the provider directly. No accounts, no subscription, no server. That's the product.

The part I want to write about is *how* it gets built. Drift ships itself, most days. A supervised autonomous loop — think Geoffrey Huntley's [Ralph loop](https://ghuntley.com/ralph/) grown up: the inner `while true` is still there, wrapped in a supervisor tree, a domain-specific state machine (GitHub issues + labels), enforcement hooks, and a live dashboard. It plans sprints, picks tickets, writes code, runs tests, does design reviews, publishes TestFlight builds, files its own product reviews, updates its own personas and roadmap, and drains its own process-feedback into the next cycle. I watch a dashboard. I course-correct when something looks off.

Deliberately *not* a general-purpose personal agent. What makes this tractable is that it's narrow — one app, one repo, one job (ship it) — with ground truth you can reconcile against (git, GitHub, `xcodebuild`). A "do anything" agent wouldn't have that.

Four patterns turned out to be non-negotiable, each from a specific, embarrassing failure:

1. **Reconcile with ground truth every tick** — don't trust state a session wrote, because sessions die mid-stamp. Read from git log and GitHub instead.
2. **Make work visible, atomically** — `next --claim` as one operation; hooks refuse to let code get written without a held claim.
3. **Liveness needs its own signal** — tool-call heartbeats, not log-file mtime (which lies during long generations).
4. **Every supervisor needs a supervisor** — `launchd` watches the watchdog.

The higher-level takeaway: the agent is not the product you own. The model will change; the scaffolding around it compounds. A solo dev with bash and a GitHub repo can build something correct enough to run without them.

Full post + zip of every hook, script, and dashboard wire so you can replicate it: [link to blog post]

#iOSDevelopment #AgenticEngineering #SoloDev #BuildInPublic
