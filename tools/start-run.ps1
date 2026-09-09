[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $ScenarioId,
  [string] $AgentLabel = 'Codex desktop',
  [Parameter(Mandatory = $true)] [string] $Model,
  [Parameter(Mandatory = $true)] [ValidateSet('none','minimal','low','medium','high','xhigh','max','ultra','not_applicable','unknown')] [string] $ReasoningEffort,
  [string] $AgentRuntimeVersion = 'unknown',
  [string] $ComputerUseRuntime = 'codex-native-windows',
  [string] $RunsRoot = "$PSScriptRoot\..\runs"
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$taskPath = Join-Path $projectRoot 'benchmark\task.json'
$task = Get-Content -Raw $taskPath | ConvertFrom-Json
$scenario = @($task.scenarios | Where-Object { $_.id -eq $ScenarioId }) | Select-Object -First 1
if ($null -eq $scenario) { throw "Unknown scenario '$ScenarioId'. See benchmark/task.json." }
$scenarioManifestPath = Join-Path $projectRoot "scenarios\$ScenarioId\scenario.json"
if (-not (Test-Path -LiteralPath $scenarioManifestPath)) { throw "Scenario '$ScenarioId' has no evaluator manifest at '$scenarioManifestPath'." }

New-Item -ItemType Directory -Force -Path $RunsRoot | Out-Null
$existing = @(Get-ChildItem -Directory -Path $RunsRoot -Filter 'run-*' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^run-\d+$' })
$next = 1
if ($existing.Count -gt 0) { $next = (($existing.Name -replace '^run-', '' | ForEach-Object { [int]$_ } | Measure-Object -Maximum).Maximum + 1) }
$runId = 'run-' + $next.ToString().PadLeft(3, '0')
$runDir = Join-Path (Resolve-Path $RunsRoot).Path $runId
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$startedAt = (Get-Date).ToUniversalTime().ToString('o')
$objective = if ($task.taskType -eq 'retrieve') { "obtain at least $($scenario.requiredCount) $($scenario.targetItem) and keep it in your player inventory" } else { "obtain at least $($scenario.requiredCount) $($scenario.targetItem) and place it in the extraction chest" }
$difficultyNote = if ($scenario.PSObject.Properties.Name -contains 'difficulty') { " The world difficulty is $($scenario.difficulty)." } else { '' }
$prompt = "You are beginning a new Minecraft benchmark task. You have no information about previous attempts. Using only the visible game and keyboard/mouse controls, $objective. Scenario: $($scenario.id).$difficultyNote Do not use commands, external tools, world files, seed information, inventory APIs, or Minecraft settings. Do not change key binds, controls, video settings, accessibility settings, resource packs, or other persistent client configuration. Stop after the item is in the required location, or when the run is no longer recoverable. For native Windows computer control, use the computer-use skill through node_repl with @oai/sky; do not use browser tabs or browser-oriented cua_repl tools. You may use the visible Minecraft Launcher only to start Minecraft Java and wait for the game window. Once the world is open, control only the exact Minecraft Java window titled Minecraft 26.2 and do not interact with the launcher. Before movement, click the center of the Minecraft viewport to restore focus, then use repeated short press_key actions with brief delays and refresh the current state after each movement cycle. If the game becomes minimized or focus is lost, reacquire the unique Minecraft 26.2 window with list_windows, activate it, click the viewport center, and continue."
$metadata = [ordered]@{
  runId = $runId
  benchmark = $task.benchmark
  version = $task.version
  scenarioId = $scenario.id
  targetItem = $scenario.targetItem
  requiredCount = $scenario.requiredCount
  timeoutSeconds = $scenario.timeoutSeconds
  worldMode = $scenario.worldMode
  difficulty = $scenario.difficulty
  agent = $AgentLabel
  startedAt = $startedAt
  isolation = [ordered]@{
    newCodexTask = $false
    cleanMinecraftSnapshot = $false
    emptyPlayerInventory = $false
    emptyExtractionChest = $false
    priorContextExcluded = $false
  }
  status = 'prepared'
  evaluator = [ordered]@{
    scenarioManifestPath = $scenarioManifestPath
    scoring = 'world-state-v1'
  }
}
$metadata | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $runDir 'metadata.json')
$prompt | Set-Content -Encoding UTF8 (Join-Path $runDir 'prompt.txt')
$promptPath = Join-Path $runDir 'prompt.txt'
$display = $null
try {
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
  $screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
    [ordered]@{ width = $_.Bounds.Width; height = $_.Bounds.Height; primary = $_.Primary }
  })
  $display = [ordered]@{ screens = $screens; primary = @($screens | Where-Object primary | Select-Object -First 1)[0] }
} catch { $display = [ordered]@{ screens = @(); primary = $null } }
$metadata.agentConfiguration = [ordered]@{
  label = $AgentLabel
  model = $Model
  reasoningEffort = $ReasoningEffort
  agentRuntimeVersion = $AgentRuntimeVersion
  computerUseRuntime = $ComputerUseRuntime
}
$metadata.executionEnvironment = [ordered]@{
  harnessVersion = 'minemark-local-v0.2'
  operatingSystem = [Environment]::OSVersion.VersionString
  display = $display
  promptSha256 = (Get-FileHash -LiteralPath $promptPath -Algorithm SHA256).Hash.ToLowerInvariant()
  timeoutSeconds = $scenario.timeoutSeconds
}
$metadata | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 (Join-Path $runDir 'metadata.json')
@('Restore using restore-scenario.ps1. Do not overwrite an existing world.', 'Run preflight-run.ps1 before opening Minecraft. It verifies the private snapshot and captures the empty starting state.', 'After Minecraft is saved and quit, run grade-run.ps1. Only its result can produce a scored success.', 'Save recording.mp4 and actions.json in this run folder. Do not put evaluator output in the agent-visible environment.') | Set-Content -Encoding UTF8 (Join-Path $runDir 'README.txt')
Write-Output "Prepared $runId"
Write-Output "Run folder: $runDir"
Write-Output "Prompt: $(Join-Path $runDir 'prompt.txt')"
