# Local run lifecycle

Minemark scores a completed run from private Minecraft save data, rather than a human observation or an agent-visible API. Keep the scenario snapshot, run folder, evaluator output, logs, and recordings outside the agent's context until the run ends.

## 1. Prepare an isolated run

~~~powershell
.\tools\start-run.ps1 -ScenarioId random-survival-peaceful-001 -Model gpt-5.6-terra -ReasoningEffort low -AgentRuntimeVersion "Codex desktop"
.\tools\reset-benchmark-runtime.ps1
.\tools\restore-scenario.ps1 -RunDir .\runs\run-001
.\tools\preflight-run.ps1 -RunDir .\runs\run-001 -WorldPath "C:\MinemarkRuntime\.minecraft\saves\Minemark-run-001"
~~~

`setup-benchmark-runtime.ps1` creates the one-time isolated Minecraft runtime at `C:\MinemarkRuntime\.minecraft` and registers the `Minemark Benchmark` Launcher installation. Use that installation for every scored attempt. `reset-benchmark-runtime.ps1` restores the fixed client settings before each run.

`restore-scenario.ps1` creates a fresh working world in the isolated runtime from the immutable snapshot and refuses to overwrite an existing world. `preflight-run.ps1` hashes that working world, verifies client settings, and captures the initial player/world state. It must pass before Minecraft is opened.

## 2. Conduct the run

Start a brand-new Codex desktop task and provide only the contents of `prompt.txt`. Open the restored world from Minecraft's single-player menu. Start the timer at the first agent action and do not coach the agent or reveal world state.

Stop on completion, death, timeout, disconnect, or an unrecoverable state. Save and quit Minecraft before grading so the save files are flushed.

## 3. Grade the saved world

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
