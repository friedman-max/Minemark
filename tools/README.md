# Local run lifecycle

Minemark scores a completed run from private Minecraft save data, rather than a human observation or an agent-visible API. Keep the scenario snapshot, run folder, evaluator output, logs, and recordings outside the agent's context until the run ends.

## One-command workflow

~~~powershell
.\tools\benchmark-run.ps1 -Mode prepare -Model gpt-5.6-terra -ReasoningEffort low -AgentRuntimeVersion "Codex desktop" -FreshTaskAttested -PriorContextExcludedAttested
~~~

This command resets the isolated client, creates the run folder, restores a fresh world, runs preflight, records model metadata, and marks the run ready. It prints the run ID, world name, and prompt path.

Use `-FreshTaskAttested` and `-PriorContextExcludedAttested` only when you will create a brand-new agent task and supply no previous benchmark context. The command cannot prove those facts itself.

After the agent has saved and quit Minecraft, grade the same run:

~~~powershell
.\tools\benchmark-run.ps1 -Mode grade -RunDir .\runs\run-010 -NoHumanInterventionAttested -TerminationReason agent_stopped
~~~

`setup-benchmark-runtime.ps1` is a one-time setup command. It creates `C:\MinemarkRuntime\.minecraft` and registers the `Minemark Benchmark` Launcher installation. Use that installation for every scored attempt.

## Manual commands

The individual scripts remain available when you need to inspect or troubleshoot a stage.

Start a brand-new Codex desktop task and provide only the contents of `prompt.txt`. Open the restored world from Minecraft's single-player menu. Start the timer at the first agent action and do not coach the agent or reveal world state.

Stop on completion, death, timeout, disconnect, or an unrecoverable state. Save and quit Minecraft before grading so the save files are flushed.

## Grading details

~~~powershell
.\tools\grade-run.ps1 -RunDir .\runs\run-001 -WorldPath "C:\MinemarkRuntime\.minecraft\saves\Minemark-run-001" -NoHumanInterventionAttested -ActionCount 123 -RecordingPath ".\runs\run-001\recording.mp4" -ActionLogPath ".\runs\run-001\actions.json" -TerminationReason agent_stopped
~~~

The grader creates `evaluator/postrun/state.json`, compares it with the preflight capture, and writes `result.json`. A success requires both objective completion (the required target is in the final player inventory) and integrity checks: fresh task, clean snapshot, empty initial inventory, Survival mode, matching difficulty, disabled commands, and a no-human-intervention attestation.

`finish-run.ps1` remains available only to preserve a manual record of failures or interrupted pilot runs. It cannot record a benchmark success.

## Scenario authoring

Each private scenario has:

- `scenario.json`: environment, task, budget, and confidentiality contract.
- `clean-snapshot/`: the immutable Minecraft world state.
- `snapshot-manifest.json`: SHA-256 manifest used by preflight.

After intentionally changing a clean snapshot, regenerate its manifest:

~~~powershell
.\tools\new-snapshot-manifest.ps1 -SnapshotPath .\scenarios\random-survival-peaceful-001\clean-snapshot -OutputPath .\scenarios\random-survival-peaceful-001\snapshot-manifest.json
~~~
