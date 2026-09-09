# Scenario setup

The previous Creative-prepared `surface-coal-001` harness is deprecated after the first invalid smoke test. The active scenario is `random-survival-peaceful-001`: a random-seed world created directly in Survival with Peaceful difficulty, commands off, and no bonus chest. Its success condition is one coal in the player inventory. The clean snapshot is in `scenarios/random-survival-peaceful-001/clean-snapshot/`.

The remainder of this document describes the future deterministic micro-world design and does not describe the active random-survival smoke test.

Use this hand-built micro-world for the first real run. The player may use Creative mode and commands while preparing the world, but switch to Survival and remove operator access before the benchmark begins.

## Current desktop harness

The first local harness is saved as `Minemark - surface-coal-001` under the Minecraft saves directory. It contains a prepared extraction chest and coal target, and the live session has been switched to Survival with `Allow Commands: OFF`. Treat this as a setup smoke test until the fairness checklist below is completed and a clean copy is made; the run must not be scored as a published benchmark result yet.

## Scenario contract

- ID: `surface-coal-001`
- Minecraft Java Edition: record the exact minor version in the run metadata.
- Mode during the run: Survival, difficulty Easy, commands unavailable to the agent.
- Spawn: a fixed platform in the center of the arena.
- Target: one exposed coal-ore block in a small, visible-but-not-immediately-adjacent cave.
- Extraction: one empty chest at the spawn platform.
- Success: the extraction chest contains at least one `minecraft:coal` item after the run.
- Timeout: 15 minutes.

## Build procedure

1. Create a new single-player world with a recorded seed and the chosen Minecraft version.
2. In Creative mode, build a sealed test arena large enough that the target cannot be reached by simply walking in a straight line. Use natural-looking terrain, but keep the target location fixed in the saved world.
3. Build a clearly marked extraction platform at the spawn point. Place exactly one empty chest there and no other usable containers.
4. Build a small cave/tunnel away from spawn and expose one coal-ore block on a wall. Ensure the player can reach it using ordinary Survival movement and a wooden or stone pickaxe.
5. Remove unintended shortcuts: no exposed target from spawn, no extra coal in chests, no command blocks, no portals, no beds, no map item, and no written signs that reveal the route.
6. Set the world spawn and player spawn to the extraction platform. Test the route yourself once, then restore the clean snapshot and empty the chest.
7. Save a read-only clean snapshot/copy outside the agent-visible environment. Keep the seed and world coordinates private for evaluation.
8. Before each run, restore the snapshot, confirm Survival mode, confirm the chest is empty, and verify the player starts with an empty inventory.

## What the agent receives

Only the standardized prompt from `start-run.ps1`. Do not tell the agent the seed, coordinates, route, target location, or evaluator rule beyond the task objective.

## Private validation

After the run ends, inspect the extraction chest from the operator/evaluator side. Record success only if it contains the required coal item. A future parser can replace this manual check without changing the task prompt, run record, or dashboard.

## Fairness checks before accepting a run

- [ ] Target is reachable without commands or unintended glitches.
- [ ] Target is not visible from the starting block.
- [ ] There is exactly one valid target source.
- [ ] Extraction chest begins empty.
- [ ] Player inventory begins empty.
- [ ] No prior recording, notes, map, or world files are agent-visible.
- [ ] A human can complete the task within the 15-minute limit using ordinary controls.
