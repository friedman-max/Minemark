# Minemark

Minemark is a benchmark for agents that play Minecraft through a visible desktop. The project is built around a simple question: can an agent complete a concrete in-world task without a game API, hidden state, or help from an operator?

The first task asks an agent to obtain a specified item and keep it in its inventory. Completion is checked from the saved Minecraft world after the run ends.

## Why Minecraft

Minecraft requires perception, movement, planning, recovery from mistakes, and interaction with a persistent world. It is a useful setting for testing agents that must turn a plan into a sequence of actions rather than return text or call a tool.

## What a run looks like

1. Start a new agent task with no prior benchmark context.
2. Restore a private Minecraft world snapshot in a dedicated game directory.
3. Verify the starting world and client settings before the agent begins.
4. Let the agent interact only through the visible Minecraft window.
5. Save and quit Minecraft.
6. Grade the player inventory and world state from private save data.

The result is `success`, `failure`, or `invalid`. Success requires both the target item and a valid run setup.

## What this repository contains

- The public task contract and result schemas
- The evaluator and run-lifecycle scripts
- A static site for explaining the benchmark and publishing approved observations
- Documentation for the isolation and grading protocol

## What stays private

Scenario seeds, world snapshots, player files, save captures, raw recordings, action logs, and unpublished results are intentionally excluded. The benchmark should be inspectable without exposing test instances to agents.

## Current status

The harness can run one isolated attempt at a time. It records the model, reasoning effort, prompt hash, display configuration, client-settings baseline, world-state evidence, and result. The next milestone is a set of scored runs across model configurations.

## Local use

Prepare a real run with one command:

~~~powershell
.\tools\benchmark-run.ps1 -Mode prepare -Model gpt-5.6-terra -ReasoningEffort low -FreshTaskAttested -PriorContextExcludedAttested
~~~

The command prints the run folder, prompt path, and restored world name. After the agent has saved and quit Minecraft, run `benchmark-run.ps1 -Mode grade` with that run folder. Full instructions are in [docs/ONE_RUN.md](docs/ONE_RUN.md). The public site can be opened directly from `index.html` or viewed at [minemark.pages.dev](https://minemark.pages.dev/).

## Contributing

The protocol is still early. Feedback on task design, isolation, scoring, and reproducibility is welcome. Please do not open an issue or pull request containing a seed, world save, player data, recording, or other private benchmark artifact.
