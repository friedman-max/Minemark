# Minemark MVP plan

## Goal

Run one objective Minecraft computer-use benchmark attempt from a clean slate, record the run, and make the protocol repeatable without giving the agent a Minecraft API.

## Current status

The evaluator is now world-state based. It reads private level data, player NBT, statistics, advancements, and logs only after save-and-quit; the agent never sees those artifacts. The active scenario has a private manifest and a 61-file immutable snapshot manifest. A clean-snapshot validation captured an empty inventory, Survival mode, Peaceful difficulty, commands disabled, and matching hashes. A no-agent validation run correctly graded invalid in a separate verification folder; no valid benchmark success has been fabricated.

## Scope for v0.1

- One task family: retrieve a specified item and keep it in the player inventory.
- One run at a time, manually started through a fresh Codex desktop task.
- Clean-slate checklist and scenario configuration.
- Private/manual evaluator contract with a stable JSON result shape.
- Browser dashboard for the benchmark contract, prompt generation, local run recording, history, and JSON export.
- No batch scheduling, model API integration, public world-save uploads, or automatic Codex-session creation.

## Completed

- [x] Replaced starter landing page with the Minemark benchmark dashboard.
- [x] Added versioned benchmark contract: `minemark-retrieve-v1`.
- [x] Added standardized prompt generation for two starter scenarios.
- [x] Added browser-local run history and JSON export.
- [x] Added fresh-run protocol and visibility restrictions to the UI.
- [x] Added repeatable local run documentation and result schema.
- [x] Added PowerShell run lifecycle scripts for preparing and finishing one run.
- [x] Added an explicit private-verification gate before a run can be finalized as successful.
- [x] Verified the run lifecycle with a labeled synthetic fixture; synthetic files were removed afterward.
- [x] Added a pre-run isolation assertion for all clean-slate gates.
- [x] Served the dashboard locally and verified browser rendering, prompt generation, run recording, and history display.
- [x] Added a deterministic first-world construction and fairness specification.
- [x] Added a dependency-free Java NBT reader for evaluator-only player inventory parsing.
- [x] Added immutable snapshot manifests, scenario manifests, restore refusal for existing worlds, and hash-checked preflight capture.
- [x] Added post-run capture and a world-state grader with separate completion and integrity outcomes.
- [x] Retired manually attested successes; only grade-run.ps1 can write a scored success.
- [x] Added a dedicated Minecraft Launcher installation with an isolated game directory and hash-checked client-settings baseline.
- [x] Added required model and reasoning-effort metadata plus prompt, control-runtime, display, OS, timeout, and evaluator configuration tracking.

## Remaining before first real run

- [x] Create one random-seed Minecraft scenario directly in Survival with commands off.
- [x] Create a clean snapshot/copy of that scenario before the first attempt.
- [x] Confirm the Codex desktop can control the visible Minecraft window.
- [ ] Run one attempt using a brand-new Codex task and the generated prompt.
- [ ] Save the screenshot/video and evaluator record under the run ID.
- [ ] Verify the end-to-end evaluator against one real Minecraft attempt.

## Current scenario

The active smoke-test scenario is `random-survival-peaceful-001`, saved in Minecraft as `Minemark - random-survival-peace`. It is a random-seed Survival world with Peaceful difficulty, no bonus chest, and commands disabled at world creation. The evaluator checks whether the player inventory contains one coal at termination. The clean snapshot is under `scenarios/random-survival-peaceful-001/clean-snapshot/`.

## Pilot and evaluator validation

Historical pilot runs remain excluded from scoring because they predate the hash-checked world-state evaluator. The new evaluator was exercised against the clean snapshot without an agent: it captured preflight and post-run state and correctly produced an invalid result because no fresh-task or no-human-intervention attestations were supplied. This validates the failure path without manufacturing a success.

## New blocker to resolve before a valid run

- [x] Produce a clean snapshot whose actual single-player host is Survival with commands unavailable.
- [x] Ensure a fresh Codex task routes to the native Windows computer-use surface (`@oai/sky`) rather than the browser-only surface before the next run.

The cause of `run-002` was confirmed in the fresh task trace: it repeatedly called browser-oriented `cua_repl` tab APIs, while the native Minecraft window is exposed through `node_repl` + `@oai/sky`. The run handoff now states this routing requirement explicitly, and `run-003` confirmed the corrected route.

## Acceptance criteria

The MVP is ready when a person can restore the scenario, start a fresh Codex task, conduct exactly one visible-computer run, determine success from the world state, record the result in the dashboard, and export a JSON record that can be compared with a later run.

## Design decisions

1. Primary scoring is binary. Time and action efficiency are secondary and must never override success.
2. The model-facing interface is only the visible game window and the task prompt.
3. The evaluator is private and authoritative; it must not report intermediate state to the agent.
4. Every attempt gets a new Codex task and a fresh Minecraft snapshot. A new browser dashboard run record is not a substitute for either.
5. The site is intentionally static so it can stay on Cloudflare Pages; local files/artifacts remain private.
