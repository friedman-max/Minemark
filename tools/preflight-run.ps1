[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $RunDir,
  [Parameter(Mandatory = $true)] [string] $WorldPath,
  [string] $PlayerUuid = '',
  [string] $RuntimeRoot = 'C:\MinemarkRuntime\.minecraft',
  [string] $MinecraftLogsPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'runtime.ps1')
$runtime = Get-MinemarkRuntimeConfig -RuntimeRoot $RuntimeRoot
if (-not $MinecraftLogsPath) { $MinecraftLogsPath = Join-Path $runtime.Root 'logs' }
$clientBaselineChecks = Assert-MinemarkClientBaseline -Runtime $runtime
$resolvedRunDir = (Resolve-Path $RunDir).Path
$metadataPath = Join-Path $resolvedRunDir 'metadata.json'
if (-not (Test-Path -LiteralPath $metadataPath)) { throw "No metadata.json found in '$resolvedRunDir'." }
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $projectRoot "scenarios\$($metadata.scenarioId)\scenario.json"
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Scenario manifest is missing: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$resolvedWorldPath = (Resolve-Path $WorldPath).Path
$runtimeSavesRoot = [IO.Path]::GetFullPath((Join-Path $runtime.Root 'saves')).TrimEnd('\') + '\'
if (-not $resolvedWorldPath.StartsWith($runtimeSavesRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw "World must be inside the isolated benchmark runtime saves directory: $runtimeSavesRoot"
}
$integrityManifestPath = Join-Path (Split-Path -Parent $manifestPath) $manifest.snapshot.integrityManifest
if (-not (Test-Path -LiteralPath $integrityManifestPath)) { throw "Snapshot integrity manifest is missing: $integrityManifestPath" }
$integrityManifest = Get-Content -LiteralPath $integrityManifestPath -Raw | ConvertFrom-Json
$snapshotFailures = @()
foreach ($entry in $integrityManifest.files) {
  $candidate = Join-Path $resolvedWorldPath ($entry.path.Replace('/', '\'))
  if (-not (Test-Path -LiteralPath $candidate)) { $snapshotFailures += "missing:$($entry.path)"; continue }
  $info = Get-Item -LiteralPath $candidate
  if ($info.Length -ne [long]$entry.bytes) { $snapshotFailures += "size:$($entry.path)"; continue }
  if ((Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) { $snapshotFailures += "hash:$($entry.path)" }
}
if ($snapshotFailures.Count -gt 0) { throw "World is not an exact restored snapshot. First failures: $((@($snapshotFailures | Select-Object -First 5)) -join ', ')" }
$out = Join-Path $resolvedRunDir 'evaluator\preflight'
& (Join-Path $PSScriptRoot 'capture-world-state.ps1') -WorldPath $WorldPath -OutputDirectory $out -Stage preflight -PlayerUuid $PlayerUuid -MinecraftLogsPath $MinecraftLogsPath
$state = Get-Content -LiteralPath (Join-Path $out 'state.json') -Raw | ConvertFrom-Json

$checks = [ordered]@{
  playerInventoryEmpty = (@($state.player.inventory.entries).Count -eq 0)
  targetAbsent = (($state.player.inventory.totals.($manifest.target.item)) -as [int]) -eq 0
  playerSurvival = ($state.player.gameMode -eq 'survival')
  worldSurvival = ($state.level.gameMode -eq 'survival')
  commandsDisabled = (-not [bool]$state.level.allowCommands)
  difficultyMatches = ($state.level.difficultyName -eq $manifest.environment.difficulty)
  snapshotManifestMatches = $true
  clientSettingsMatchBaseline = -not ($clientBaselineChecks.Values -contains $false)
}
if (-not ($checks.Values -notcontains $false)) {
  $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
  throw "Preflight failed: $($failed -join ', '). This run cannot be scored."
}
$metadata.isolation.cleanMinecraftSnapshot = $true
$metadata.isolation.emptyPlayerInventory = $true
$worldState = [ordered]@{
  manifestPath = $manifestPath
  preflightStatePath = (Join-Path $out 'state.json')
  activeWorldPath = $resolvedWorldPath
  playerUuid = $state.playerUuid
  runtimeRoot = $runtime.Root
  clientBaselineChecks = $clientBaselineChecks
  preflightChecks = $checks
}
if ($metadata.PSObject.Properties.Name -contains 'worldState') { $metadata.worldState = $worldState } else { $metadata | Add-Member -NotePropertyName worldState -NotePropertyValue $worldState }
$metadata.status = 'preflight_captured'
$metadata | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
Write-Output "Preflight captured for $($metadata.runId). Set newCodexTask and priorContextExcluded in metadata.json, then run assert-isolated.ps1."
