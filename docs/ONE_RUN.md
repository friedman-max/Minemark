# Minemark one-run operating procedure

This is the repeatable protocol for one candidate benchmark run. The agent never receives the seed, snapshot, save data, evaluator files, historical results, or post-run state.

## Before the run

1. Use the dedicated `Minemark Benchmark` Launcher installation, whose game directory is `C:\MinemarkRuntime\.minecraft`. It is isolated from the everyday Minecraft profile.
2. Run `reset-benchmark-runtime.ps1`, then create a run with `start-run.ps1`, explicitly providing the model and reasoning effort, and restore its named scenario with `restore-scenario.ps1`.
3. Run `preflight-run.ps1` against the restored world. It must pass all checks: byte-for-byte snapshot match, baseline client settings, empty inventory, target absent, Survival mode, expected difficulty, and commands disabled.
4. Start a brand-new Codex task. Do not follow up on any benchmark task and do not make prior benchmark material agent-visible.
5. Give the agent only the generated `prompt.txt`. It may use visible desktop control to operate Minecraft; it does not receive a Minecraft API or evaluator endpoint.
6. Start recording and the timer at the first agent action.

## During the run

1. The agent enters the restored world through Minecraft's normal single-player interface.
2. Do not provide hints, intervene in the game, or expose private evaluator information.
3. End at completion, death, timeout, disconnect, or unrecoverable state.
4. Save and quit Minecraft completely before evaluation. This flushes the player NBT and statistics files.

## After the run

1. Privately preserve the recording and, when available, the computer-control action log.
2. Run `grade-run.ps1` with the run directory and the working world path. Supply `-NoHumanInterventionAttested` only when true.
3. Retain the resulting `result.json`, plus the captures in `evaluator/preflight` and `evaluator/postrun`. These are the audit artifacts for the run.
4. Treat a run as scored only when its result is `success`, which requires both completion and integrity. `failure` means the target was not completed under valid conditions; `invalid` means a protocol check failed.
5. Reset the benchmark runtime before the next attempt. Never reuse the working world for another scored attempt; restore a new scenario world first.

## What is objectively verified

The evaluator reads the Java world save after the game closes. For the current retrieve task it checks that the player has the requested item in final inventory and records statistics deltas, player state, world settings, and hashes of copied save artifacts. Logs and video are diagnostic evidence, not the authoritative success signal.

Each run also records the exact model, reasoning effort, agent/runtime version, computer-control runtime, prompt hash, timeout, display layout, operating system, scenario, and Minecraft version. Model and effort are required inputs when the run is created; use `unknown` only when a provider does not disclose one.

## Current boundary

The v1 evaluator establishes outcome and run integrity, not a cryptographic proof that every input came from the agent. Video and the action log remain valuable audit evidence. The dedicated game directory plus a reset/hash check prevents an agent's changed keybinds or settings from leaking into another run. Future scenario variants can add task-specific provenance checks while reusing the same snapshot, preflight, capture, and grading framework.
