[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $RunDir,
  [Parameter(Mandatory = $true)] [string] $WorldPath,
  [switch] $NoHumanInterventionAttested,
  [string] $RuntimeRoot = 'C:\MinemarkRuntime\.minecraft',
  [string] $MinecraftLogsPath = '',
  [Nullable[int]] $ActionCount,
  [string] $RecordingPath = '',
  [string] $ActionLogPath = '',
  [string] $TerminationReason = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'runtime.ps1')
$runtime = Get-MinemarkRuntimeConfig -RuntimeRoot $RuntimeRoot
if (-not $MinecraftLogsPath) { $MinecraftLogsPath = Join-Path $runtime.Root 'logs' }
function Get-Number($value) { if ($null -eq $value) { return 0 }; return [int]$value }
function Get-Stat($state, $category, $item) { $bucket = $state.statistics.$category; if ($null -eq $bucket) { return 0 }; return Get-Number $bucket.$item }

$resolvedRunDir = (Resolve-Path $RunDir).Path
$metadataPath = Join-Path $resolvedRunDir 'metadata.json'
if (-not (Test-Path -LiteralPath $metadataPath)) { throw "No metadata.json found in '$resolvedRunDir'." }
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
if (-not $metadata.worldState.preflightStatePath) { throw 'No captured preflight state. Run preflight-run.ps1 before starting the agent.' }
$preflightPath = $metadata.worldState.preflightStatePath
if (-not (Test-Path -LiteralPath $preflightPath)) { throw "Preflight state is missing: $preflightPath" }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $projectRoot "scenarios\$($metadata.scenarioId)\scenario.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$resolvedWorldPath = (Resolve-Path $WorldPath).Path
$runtimeSavesRoot = [IO.Path]::GetFullPath((Join-Path $runtime.Root 'saves')).TrimEnd('\') + '\'
if (-not $resolvedWorldPath.StartsWith($runtimeSavesRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw "World must be inside the isolated benchmark runtime saves directory: $runtimeSavesRoot"
}
$postDir = Join-Path $resolvedRunDir 'evaluator\postrun'
& (Join-Path $PSScriptRoot 'capture-world-state.ps1') -WorldPath $WorldPath -OutputDirectory $postDir -Stage postrun -PlayerUuid $metadata.worldState.playerUuid -MinecraftLogsPath $MinecraftLogsPath
$pre = Get-Content -LiteralPath $preflightPath -Raw | ConvertFrom-Json
$post = Get-Content -LiteralPath (Join-Path $postDir 'state.json') -Raw | ConvertFrom-Json

$target = $manifest.target.item
$required = [int]$manifest.target.minimumCount
$initial = Get-Number $pre.player.inventory.totals.$target
$final = Get-Number $post.player.inventory.totals.$target
$completion = ($initial -eq 0 -and $final -ge $required)
$integrity = [ordered]@{
  newCodexTask = [bool]$metadata.isolation.newCodexTask
  priorContextExcluded = [bool]$metadata.isolation.priorContextExcluded
  cleanMinecraftSnapshot = [bool]$metadata.isolation.cleanMinecraftSnapshot
  emptyPlayerInventory = [bool]$metadata.isolation.emptyPlayerInventory
  initialTargetAbsent = ($initial -eq 0)
  finalPlayerSurvival = ($post.player.gameMode -eq 'survival')
  finalWorldSurvival = ($post.level.gameMode -eq 'survival')
  commandsDisabled = (-not [bool]$post.level.allowCommands)
  difficultyMatches = ($post.level.difficultyName -eq $manifest.environment.difficulty)
  isolatedRuntimeMatches = ($metadata.worldState.runtimeRoot -eq $runtime.Root)
  postrunWorldMatchesPreflight = ($resolvedWorldPath -eq $metadata.worldState.activeWorldPath)
  noHumanInterventionAttested = [bool]$NoHumanInterventionAttested
}
$integrityPass = -not ($integrity.Values -contains $false)
$pickedUpDelta = (Get-Stat $post 'minecraft:picked_up' $target) - (Get-Stat $pre 'minecraft:picked_up' $target)
$minedDelta = (Get-Stat $post 'minecraft:mined' 'minecraft:coal_ore') - (Get-Stat $pre 'minecraft:mined' 'minecraft:coal_ore')
$deaths = (Get-Stat $post 'minecraft:custom' 'minecraft:deaths') - (Get-Stat $pre 'minecraft:custom' 'minecraft:deaths')
$elapsed = [math]::Round(([datetime]$post.capturedAt - [datetime]$pre.capturedAt).TotalSeconds, 3)
$outcome = if ($completion -and $integrityPass) { 'success' } elseif (-not $integrityPass) { 'invalid' } else { 'failure' }
$result = [ordered]@{
  schemaVersion = 'minemark-run-result-v2'
  runId = $metadata.runId
  benchmark = $metadata.benchmark
  protocolVersion = $metadata.version
  scenarioId = $metadata.scenarioId
  agent = $metadata.agentConfiguration
  executionEnvironment = $metadata.executionEnvironment
  target = [ordered]@{ item = $target; requiredCount = $required; initialCount = $initial; finalCount = $final }
  startedAt = $metadata.startedAt
  endedAt = $post.capturedAt
  outcome = $outcome
  primarySuccess = ($outcome -eq 'success')
  completion = [ordered]@{ pass = $completion; verifier = 'player_inventory_nbt' }
  integrity = [ordered]@{ pass = $integrityPass; checks = $integrity }
  metrics = [ordered]@{
    elapsedSeconds = $elapsed
    deaths = $deaths
    actionCount = $ActionCount
    targetPickedUpDelta = $pickedUpDelta
    coalOreMinedDelta = $minedDelta
    terminationReason = if ($TerminationReason) { $TerminationReason } else { $null }
  }
  evaluator = 'world-state-v1'
  artifacts = [ordered]@{
    preflightStatePath = $preflightPath
    postrunStatePath = (Join-Path $postDir 'state.json')
    recordingPath = if ($RecordingPath) { $RecordingPath } else { $null }
    actionLogPath = if ($ActionLogPath) { $ActionLogPath } else { $null }
  }
}
$result | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath (Join-Path $resolvedRunDir 'result.json') -Encoding UTF8
$metadata.status = 'graded'
if ($metadata.PSObject.Properties.Name -contains 'endedAt') { $metadata.endedAt = $post.capturedAt } else { $metadata | Add-Member -NotePropertyName endedAt -NotePropertyValue $post.capturedAt }
if ($metadata.worldState.PSObject.Properties.Name -contains 'postrunStatePath') { $metadata.worldState.postrunStatePath = (Join-Path $postDir 'state.json') } else { $metadata.worldState | Add-Member -NotePropertyName postrunStatePath -NotePropertyValue (Join-Path $postDir 'state.json') }
$metadata | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
Write-Output "Graded $($metadata.runId): $outcome (completion=$completion, integrity=$integrityPass)"
