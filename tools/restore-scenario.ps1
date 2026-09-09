[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $RunDir,
  [string] $RuntimeRoot = 'C:\MinemarkRuntime\.minecraft',
  [string] $MinecraftSavesRoot = '',
  [string] $DestinationWorldName = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'runtime.ps1')
$runtime = Get-MinemarkRuntimeConfig -RuntimeRoot $RuntimeRoot
if (-not $MinecraftSavesRoot) { $MinecraftSavesRoot = Join-Path $runtime.Root 'saves' }
$resolvedRunDir = (Resolve-Path $RunDir).Path
$metadata = Get-Content -LiteralPath (Join-Path $resolvedRunDir 'metadata.json') -Raw | ConvertFrom-Json
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scenarioRoot = Join-Path $projectRoot "scenarios\$($metadata.scenarioId)"
$manifest = Get-Content -LiteralPath (Join-Path $scenarioRoot 'scenario.json') -Raw | ConvertFrom-Json
$snapshotPath = Join-Path $scenarioRoot $manifest.snapshot.path
if (-not (Test-Path -LiteralPath $snapshotPath)) { throw "Snapshot is missing: $snapshotPath" }
if (-not $DestinationWorldName) { $DestinationWorldName = "Minemark-$($metadata.runId)" }
if ($DestinationWorldName -match '[\\/:*?"<>|]') { throw 'DestinationWorldName contains characters invalid in a Windows folder name.' }
New-Item -ItemType Directory -Force -Path $MinecraftSavesRoot | Out-Null
$destination = Join-Path (Resolve-Path $MinecraftSavesRoot).Path $DestinationWorldName
if (Test-Path -LiteralPath $destination) { throw "Refusing to overwrite existing world: $destination. Choose a new DestinationWorldName." }
Copy-Item -LiteralPath $snapshotPath -Destination $destination -Recurse
Write-Output "Restored $($metadata.scenarioId) to $destination"
Write-Output 'Run preflight-run.ps1 before opening this world in Minecraft; it verifies both the snapshot and isolated client settings before gameplay can modify them.'
